import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../core/utils/icon_util.dart';

enum TimeRange { today, month, year }

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  TimeRange _timeRange = TimeRange.month;
  int _selectedType = 0; // 0: 支出, 1: 收入

  int _touchedIndex = -1;

  final List<Color> _chartColors = [
    Colors.blue,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.purple,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.indigo,
    Colors.lightGreen,
    Colors.brown,
    Colors.redAccent,
    Colors.blueGrey,
    Colors.lime,
    Colors.grey,
  ];

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '收支统计',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          return categoriesAsync.when(
            data: (categories) {
              // 1. 根据时间筛选
              final now = DateTime.now();
              final filteredTxs = transactions.where((t) {
                final date = DateTime.fromMillisecondsSinceEpoch(t.timestamp);
                switch (_timeRange) {
                  case TimeRange.today:
                    return date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;
                  case TimeRange.month:
                    return date.year == now.year && date.month == now.month;
                  case TimeRange.year:
                    return date.year == now.year;
                }
              }).toList();

              // 2. 根据类型聚集金额并计算总额
              double totalAmount = 0;
              final Map<int, double> categoryTotals = {};
              for (var t in filteredTxs) {
                if (t.type == _selectedType) {
                  totalAmount += t.amount;
                  categoryTotals[t.categoryId] =
                      (categoryTotals[t.categoryId] ?? 0) + t.amount;
                }
              }

              // 3. 构建排序后的图表数据格式
              final sortedEntries = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                children: [
                  _buildHeaderFilters(),
                  Expanded(
                    child: sortedEntries.isEmpty
                        ? const Center(
                            child: Text(
                              '该时段内无记录',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _buildChartCard(
                                  sortedEntries,
                                  totalAmount,
                                  categories,
                                ),
                              ),
                              SliverToBoxAdapter(child: _buildListHeader()),
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final entry = sortedEntries[index];
                                  final categoryName =
                                      categories
                                          .where((c) => c.id == entry.key)
                                          .firstOrNull
                                          ?.name ??
                                      '未知';
                                  final percentage = totalAmount > 0
                                      ? (entry.value / totalAmount * 100)
                                      : 0.0;
                                  final color =
                                      _chartColors[index % _chartColors.length];

                                  return _buildCategoryListItem(
                                    categoryName,
                                    entry.value,
                                    percentage,
                                    color,
                                  );
                                }, childCount: sortedEntries.length),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 40),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const Center(child: Text('分类加载失败')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('数据加载失败')),
      ),
    );
  }

  Widget _buildHeaderFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          SegmentedButton<TimeRange>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            segments: const [
              ButtonSegment(value: TimeRange.today, label: Text('今日')),
              ButtonSegment(value: TimeRange.month, label: Text('本月')),
              ButtonSegment(value: TimeRange.year, label: Text('本年')),
            ],
            selected: {_timeRange},
            onSelectionChanged: (Set<TimeRange> newSelection) {
              setState(() {
                _timeRange = newSelection.first;
                _touchedIndex = -1; // reset chart selection
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _buildTypeTab(0, '支出明细')),
                Expanded(child: _buildTypeTab(1, '收入明细')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(int type, String title) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _touchedIndex = -1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(
    List<MapEntry<int, double>> entries,
    double totalAmount,
    categories,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            _selectedType == 0 ? '总支出 (元)' : '总收入 (元)',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            totalAmount.toStringAsFixed(2),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: _buildChartSections(entries, totalAmount, categories),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(
    List<MapEntry<int, double>> entries,
    double total,
    categories,
  ) {
    return List.generate(entries.length, (i) {
      final isTouched = i == _touchedIndex;
      final entry = entries[i];
      final percentage = total > 0 ? (entry.value / total * 100) : 0.0;

      final radius = isTouched ? 60.0 : 50.0;
      final fontSize = isTouched ? 16.0 : 12.0;

      return PieChartSectionData(
        color: _chartColors[i % _chartColors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildListHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        '排行榜',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCategoryListItem(
    String categoryName,
    double amount,
    double percentage,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              IconUtil.getCategoryIcon(categoryName),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage / 100.0,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
