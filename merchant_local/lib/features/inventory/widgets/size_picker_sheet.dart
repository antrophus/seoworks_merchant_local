import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// size_charts 기반 탭형 사이즈 피커 (바텀시트)
///
/// 브랜드명을 기반으로 MEN/WOMEN/KIDS 탭을 표시하고,
/// 사이즈 행 클릭 시 KR/EU/US 값을 콜백으로 전달합니다.
/// size_charts 데이터가 없으면 수동 입력 모드로 전환됩니다.
class SizePickerResult {
  final String kr;
  final String? eu;
  final String? us;
  final String? uk;

  const SizePickerResult({
    required this.kr,
    this.eu,
    this.us,
    this.uk,
  });
}

Future<SizePickerResult?> showSizePickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String brandName,
  String? category,
}) async {
  // 카테고리가 신발이 아닌 경우 → 수동 입력
  final isFootwear = category == null ||
      category.isEmpty ||
      ['sneakers', 'shoes', 'boots', 'sandals', 'slippers']
          .any((c) => category.toLowerCase().contains(c));

  if (!isFootwear) {
    if (!context.mounted) return null;
    return _showManualSizeInput(context);
  }

  // 사이즈차트 확인
  final targets =
      await ref.read(masterDaoProvider).getSizeChartTargets(brandName);
  if (targets.isEmpty) {
    if (!context.mounted) return null;
    return _showManualSizeInput(context);
  }

  if (!context.mounted) return null;
  return showModalBottomSheet<SizePickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SizePickerBody(
      ref: ref,
      brandName: brandName,
      targets: targets,
    ),
  );
}

Future<SizePickerResult?> _showManualSizeInput(BuildContext context) async {
  final krCtrl = TextEditingController();
  final euCtrl = TextEditingController();

  return showDialog<SizePickerResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('사이즈 입력'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: krCtrl,
            decoration: const InputDecoration(
              labelText: 'KR 사이즈',
              hintText: '270 또는 L',
            ),
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: euCtrl,
            decoration: const InputDecoration(
              labelText: 'EU 사이즈 (선택)',
              hintText: '42.5',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final kr = krCtrl.text.trim();
            if (kr.isEmpty) return;
            Navigator.pop(
              ctx,
              SizePickerResult(
                kr: kr,
                eu: euCtrl.text.trim().isNotEmpty ? euCtrl.text.trim() : null,
              ),
            );
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class _SizePickerBody extends StatefulWidget {
  final WidgetRef ref;
  final String brandName;
  final List<String> targets;

  const _SizePickerBody({
    required this.ref,
    required this.brandName,
    required this.targets,
  });

  @override
  State<_SizePickerBody> createState() => _SizePickerBodyState();
}

class _SizePickerBodyState extends State<_SizePickerBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SizeChartData> _sizes = [];
  bool _loading = true;

  String get _targetLabel => switch (widget.targets[_tabController.index]) {
        'MEN' => '남성',
        'WOMEN' => '여성',
        'KIDS' => '키즈',
        _ => widget.targets[_tabController.index],
      };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.targets.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadSizes();
    });
    _loadSizes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSizes() async {
    setState(() => _loading = true);
    final target = widget.targets[_tabController.index];
    final sizes = await widget.ref
        .read(masterDaoProvider)
        .getSizeChartsByBrandAndTarget(widget.brandName, target);
    if (mounted) {
      setState(() {
        _sizes = sizes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '${widget.brandName} 사이즈',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final result = await _showManualSizeInput(context);
                      if (result != null && mounted) {
                        nav.pop(result);
                      }
                    },
                    child: const Text('직접 입력'),
                  ),
                ],
              ),
            ),

            // 탭
            if (widget.targets.length > 1)
              TabBar(
                controller: _tabController,
                tabs: widget.targets
                    .map((t) => Tab(
                          text: switch (t) {
                            'MEN' => '남성',
                            'WOMEN' => '여성',
                            'KIDS' => '키즈',
                            _ => t,
                          },
                        ))
                    .toList(),
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
              ),

            // 사이즈 목록
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : _sizes.isEmpty
                      ? Center(
                          child: Text(
                            '$_targetLabel 사이즈 데이터가 없습니다',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textTertiary),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          itemCount: _sizes.length + 1, // +1 for header
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            if (i == 0) return _buildHeader(context);
                            final size = _sizes[i - 1];
                            return _buildRow(context, size);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text('KR', style: style)),
          SizedBox(width: 60, child: Text('EU', style: style)),
          SizedBox(width: 60, child: Text('US', style: style)),
          SizedBox(width: 60, child: Text('UK', style: style)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, SizeChartData size) {
    final dataStyle = AppTheme.dataStyle(fontSize: 13);

    return InkWell(
      onTap: () {
        final kr = size.kr;
        // 정수인 경우 소수점 제거 (270.0 → 270)
        final krStr = kr == kr.roundToDouble()
            ? kr.toInt().toString()
            : kr.toString();

        Navigator.pop(
          context,
          SizePickerResult(
            kr: krStr,
            eu: size.eu,
            us: size.usM ?? size.us,
            uk: size.uk,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                size.kr == size.kr.roundToDouble()
                    ? size.kr.toInt().toString()
                    : size.kr.toString(),
                style: dataStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(size.eu ?? '-', style: dataStyle),
            ),
            SizedBox(
              width: 60,
              child: Text(size.usM ?? size.us ?? '-', style: dataStyle),
            ),
            SizedBox(
              width: 60,
              child: Text(size.uk ?? '-', style: dataStyle),
            ),
          ],
        ),
      ),
    );
  }
}
