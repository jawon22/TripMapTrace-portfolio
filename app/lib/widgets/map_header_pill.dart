import 'package:flutter/material.dart';
import '../theme/app_radius.dart';

/// 지도 상단에 떠 있는 정체성 헤더 pill. 지도 3곳(글로벌·여행·커뮤니티)이 공유한다.
/// 흰 배경·둥근 모서리·그림자. [trailing]에 지역 칩 등 부가 요소를 넣을 수 있다.
class MapHeaderPill extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const MapHeaderPill({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md * 2), // 24
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
