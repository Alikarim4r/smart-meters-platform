import 'dart:io';

/// Locates the synthetic demo network snapshot from the repository root.
///
/// Resolved by walking up from the current directory rather than hard-coding an
/// absolute path: the previous fixtures pointed inside one developer's home
/// directory, so those tests could only pass on that machine and failed on
/// every CI runner.
File demoSnapshotFile() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File(
      '${dir.path}/demo_data/demo_network_snapshot.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  // Return the conventional location so the failure message names a real path.
  return File('${Directory.current.path}/demo_data/demo_network_snapshot.json');
}
