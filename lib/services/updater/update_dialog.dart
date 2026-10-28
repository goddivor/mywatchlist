import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

import 'release_service.dart';
import 'update_controller.dart';

/// "Check for updates": looks at the newest GitHub release, then downloads, verifies and
/// installs the APK for this device. Every state ends with a way out (Close, Retry, or the
/// release page).
class UpdateDialog extends StatefulWidget {
  final String current;
  final ReleaseService releases;
  final UpdateEnvironment? environment;
  final void Function(String url) onOpen;

  const UpdateDialog({
    super.key,
    required this.current,
    required this.releases,
    required this.onOpen,
    this.environment,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late final UpdateController _controller = UpdateController(
    currentVersion: widget.current,
    releases: widget.releases,
    env: widget.environment ?? UpdateEnvironment.device(),
  );

  @override
  void initState() {
    super.initState();
    _controller.check();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _viewRelease() {
    final url = _controller.release?.url ?? '$updaterRepoUrl/releases';
    _close();
    widget.onOpen(url);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final busy = c.phase == UpdatePhase.downloading || c.phase == UpdatePhase.verifying;
        return PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(_title(c)),
            content: _Content(controller: c),
            actions: _actions(c),
          ),
        );
      },
    );
  }

  String _title(UpdateController c) {
    switch (c.phase) {
      case UpdatePhase.checking:
        return S.current.Abt_Checking;
      case UpdatePhase.noRelease:
      case UpdatePhase.failed:
        return S.current.Check_for_updates;
      case UpdatePhase.upToDate:
        return S.current.Abt_Up_To_Date;
      case UpdatePhase.available:
        return S.current.Update_available;
      case UpdatePhase.downloading:
        return S.current.Downloading_update;
      case UpdatePhase.verifying:
        return S.current.Upd_Verifying;
      case UpdatePhase.installing:
        return S.current.Installing_update;
    }
  }

  List<Widget> _actions(UpdateController c) {
    final close = TextButton(onPressed: _close, child: Text(S.current.Close));
    final view = TextButton(onPressed: _viewRelease, child: Text(S.current.Abt_View_Release));
    switch (c.phase) {
      case UpdatePhase.checking:
      case UpdatePhase.noRelease:
      case UpdatePhase.upToDate:
        return [close];
      case UpdatePhase.available:
        return [
          close,
          view,
          if (c.supported)
            FilledButton(
              onPressed: c.downloadAndInstall,
              child: Text(S.current.Upd_Download_Install),
            ),
        ];
      case UpdatePhase.downloading:
        return [TextButton(onPressed: c.cancel, child: Text(S.current.Cancel))];
      case UpdatePhase.verifying:
        return const [];
      case UpdatePhase.installing:
        return [
          close,
          FilledButton(onPressed: c.downloadAndInstall, child: Text(S.current.Upd_Install_Again)),
        ];
      case UpdatePhase.failed:
        final f = c.failure;
        final needsPage = f == UpdateFailure.noApk ||
            f == UpdateFailure.checksumMissing ||
            f == UpdateFailure.checksumMismatch;
        return [
          close,
          if (needsPage && c.release != null) view,
          if (f != UpdateFailure.noApk && f != UpdateFailure.checksumMissing)
            FilledButton(onPressed: c.retry, child: Text(S.current.Abt_Try_Again)),
        ];
    }
  }
}

class _Content extends StatelessWidget {
  final UpdateController controller;

  const _Content({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final c = controller;
    switch (c.phase) {
      case UpdatePhase.checking:
        return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
      case UpdatePhase.noRelease:
        return Text(S.current.Upd_No_Release);
      case UpdatePhase.upToDate:
        return Text(S.current.Abt_Up_To_Date_Desc(controller.currentVersion));
      case UpdatePhase.available:
        final release = c.release!;
        final choice = pickLabel(c);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.current.Abt_Update_Desc(release.tag, c.currentVersion)),
            if (!c.supported) ...[
              const SizedBox(height: 12),
              Text(S.current.Upd_Unsupported,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ] else if (choice != null) ...[
              const SizedBox(height: 12),
              Text(choice, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ],
        );
      case UpdatePhase.downloading:
        final total = c.total;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: c.progress, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
            Text(
              total == null
                  ? S.current.Upd_Progress_Unknown(formatBytes(c.received))
                  : S.current.Upd_Progress(formatBytes(c.received), formatBytes(total)),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        );
      case UpdatePhase.verifying:
        return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
      case UpdatePhase.installing:
        return Text(S.current.Upd_Install_Started);
      case UpdatePhase.failed:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(_failureText(c.failure))),
          ],
        );
    }
  }

  /// The file that would be downloaded (name and size), null when the release has none for
  /// this device.
  static String? pickLabel(UpdateController c) {
    final apk = c.choice?.apk;
    if (apk == null) return null;
    return apk.size > 0 ? S.current.Upd_Package(apk.name, formatBytes(apk.size)) : apk.name;
  }

  static String _failureText(UpdateFailure? f) {
    switch (f) {
      case UpdateFailure.check:
      case null:
        return S.current.Abt_Load_Failed;
      case UpdateFailure.noApk:
        return S.current.Upd_No_Apk;
      case UpdateFailure.download:
        return S.current.Upd_Download_Failed_Desc;
      case UpdateFailure.checksumMissing:
        return S.current.Upd_Checksum_Missing;
      case UpdateFailure.checksumMismatch:
        return S.current.Upd_Checksum_Failed;
      case UpdateFailure.permission:
        return S.current.Upd_Permission_Needed;
      case UpdateFailure.install:
        return S.current.Upd_Install_Failed;
    }
  }
}
