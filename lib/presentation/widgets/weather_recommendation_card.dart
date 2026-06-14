import 'package:flutter/material.dart';
import 'package:plantapp_p/presentation/app_colors.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';

/// 날씨 기반 오늘의 식물 케어 추천 카드
///
/// - 전체 식물 보기에서만 ListView 최상단에 표시
/// - 로딩 중: 스켈레톤 shimmer 스타일 플레이스홀더
/// - 성공: Gemini가 생성한 추천 멘트 표시
/// - 오류: 카드 자체를 숨김 (HomeScreen의 showWeatherCard 조건에서 처리)
class WeatherRecommendationCard extends StatelessWidget {
  const WeatherRecommendationCard({
    super.key,
    required this.viewModel,
    required this.onRetry,
  });

  final HomeViewModel viewModel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.primaryGreen.withOpacity(0.18),
                    colorScheme.surface,
                  ]
                : [
                    AppColors.primaryGreen.withOpacity(0.10),
                    Colors.white,
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.30),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildContent(context, colorScheme),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    switch (viewModel.recommendationStatus) {
      case RecommendationStatus.loading:
        return _buildSkeleton(colorScheme);
      case RecommendationStatus.success:
        return _buildRecommendation(context, colorScheme);
      case RecommendationStatus.idle:
      case RecommendationStatus.error:
        return _buildSkeleton(colorScheme);
    }
  }

  Widget _buildRecommendation(BuildContext context, ColorScheme colorScheme) {
    final now = DateTime.now();
    final isEvening = now.hour >= 18;
    final slotLabel = isEvening ? '내일 날씨 예상' : '오늘 날씨 예상';
    final slotIcon = isEvening ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(slotIcon, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text(
              slotLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.eco_outlined,
              size: 14,
              color: colorScheme.onSurface.withOpacity(0.35),
            ),
            const SizedBox(width: 3),
            Text(
              'AI 케어 알림',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withOpacity(0.35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          viewModel.recommendationText ?? '',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: colorScheme.onSurface.withOpacity(0.88),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(ColorScheme colorScheme) {
    final baseColor = colorScheme.onSurface.withOpacity(0.08);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 90,
              height: 12,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 180,
          height: 12,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
