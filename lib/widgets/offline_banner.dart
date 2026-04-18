import 'package:flutter/material.dart';
import '../services/offline_sync_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineSyncService.instance.isOnline,
      builder: (context, online, _) {
        if (online) {
          // When online, show syncing indicator if actively syncing
          return ValueListenableBuilder<SyncStatus>(
            valueListenable: OfflineSyncService.instance.syncStatus,
            builder: (context, status, _) {
              if (status == SyncStatus.syncing) {
                return _buildBanner(
                  context,
                  color: Colors.orange.shade700,
                  icon: Icons.sync,
                  text: 'Syncing offline actions...',
                  showSpinner: true,
                );
              }
              return const SizedBox.shrink();
            },
          );
        }

        // Offline state
        return ValueListenableBuilder<int>(
          valueListenable: OfflineSyncService.instance.pendingCount,
          builder: (context, count, _) {
            final text = count > 0
                ? 'You\'re offline  -  $count pending action${count == 1 ? '' : 's'}'
                : 'You\'re offline';
            return _buildBanner(
              context,
              color: Colors.red.shade700,
              icon: Icons.cloud_off_rounded,
              text: text,
              showSpinner: false,
            );
          },
        );
      },
    );
  }

  Widget _buildBanner(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String text,
    required bool showSpinner,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showSpinner)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
