import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../providers/preferences_providers.dart';
import '../theme/entry_chrome.dart';

/// Full-screen profile editor opened from the settings header.
class EntryProfileEditScreen extends ConsumerStatefulWidget {
  const EntryProfileEditScreen({super.key});

  @override
  ConsumerState<EntryProfileEditScreen> createState() =>
      _EntryProfileEditScreenState();
}

class _EntryProfileEditScreenState
    extends ConsumerState<EntryProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _phoneController;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarContentType;
  bool _saving = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _companyController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _seed(Profile? profile) {
    if (_seeded || profile == null) return;
    _nameController.text = profile.fullName;
    _companyController.text = profile.companyName ?? '';
    _phoneController.text = profile.phone ?? '';
    _seeded = true;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pendingAvatarBytes = bytes;
      _pendingAvatarContentType = file.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _save(EntryStrings s) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    setState(() => _saving = true);
    try {
      String? avatarPath = profile.avatarPath;
      if (_pendingAvatarBytes != null) {
        avatarPath = await ref.read(profileRepositoryProvider).uploadAvatar(
              userId: profile.id,
              bytes: _pendingAvatarBytes!,
              contentType: _pendingAvatarContentType ?? 'image/jpeg',
            );
      }
      await ref.read(authProvider.notifier).updateOwnProfile(
            fullName: _nameController.text.trim(),
            companyName: _companyController.text.trim(),
            phone: _phoneController.text.trim(),
            avatarPath: avatarPath,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.profileSaved)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final profile = ref.watch(authProvider).profile;
    _seed(profile);

    final displayName = profile == null
        ? ''
        : (profile.fullName.trim().isEmpty ? profile.email : profile.fullName);
    final initials = _initials(displayName);
    final avatarUrl = profile == null
        ? null
        : ref.read(profileRepositoryProvider).publicAvatarUrl(profile.avatarPath);

    ImageProvider? image;
    if (_pendingAvatarBytes != null) {
      image = MemoryImage(_pendingAvatarBytes!);
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      image = NetworkImage(avatarUrl);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.editProfile),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: InkWell(
                  onTap: _saving ? null : _pickAvatar,
                  borderRadius: BorderRadius.circular(48),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: EntryChrome.accent,
                        backgroundImage: image,
                        child: image == null
                            ? Text(
                                initials,
                                style: TextStyle(
                                  color: EntryChrome.onAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _pendingAvatarBytes != null ||
                                (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? s.changePhoto
                            : s.addProfilePhoto,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: EntryChrome.iconGlyph,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: s.fullName,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? s.nameRequired
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyController,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: s.companyName,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: s.phone,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(s),
                  icon: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EntryChrome.onAccent,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? s.saving : s.saveProfile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
