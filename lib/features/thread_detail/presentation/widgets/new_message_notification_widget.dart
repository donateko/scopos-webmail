import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:core/presentation/resources/image_paths.dart';

class NewMessageNotificationWidget extends StatelessWidget {
  const NewMessageNotificationWidget({
    super.key,
    required this.onRefreshTap,
    required this.onDismiss,
    required this.imagePaths,
  });

  final VoidCallback onRefreshTap;
  final VoidCallback onDismiss;
  final ImagePaths imagePaths;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mail,
            color: Colors.blue[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'New message received',
              style: ThemeUtils.textStyleBodyBody2(
                fontWeight: FontWeight.w500,
                color: Colors.blue[800],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRefreshTap,
            icon: Icon(
              Icons.refresh,
              size: 16,
              color: Colors.blue[700],
            ),
            label: Text(
              'Refresh',
              style: ThemeUtils.textStyleBodyBody2(
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
