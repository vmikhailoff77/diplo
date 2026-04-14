import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'movements_database.dart';

class AnalyticsReport extends StatefulWidget {
  final Map<String, dynamic> product;

  const AnalyticsReport({super.key, required this.product});

  @override
  State<AnalyticsReport> createState() => _AnalyticsReportState();
}

class _AnalyticsReportState extends State<AnalyticsReport> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = false;

  // Статистика
  int _totalIncome = 0;
  int _totalExpense = 0;
  int _totalStockChange = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final movements = await MovementsDatabase().getMovements(
        productUuid: widget.product['uuid'],
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
      );

      setState(() {
        _movements = movements;
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Ошибка загрузки: $e');
    }
  }

  Future<void> _loadAllTimeData() async {
    setState(() => _isLoading = true);
    try {
      final movements = await MovementsDatabase().getAllMovementsForProduct(
        widget.product['uuid'],
      );
      setState(() {
        _movements = movements;
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _calculateStats() {
    _totalIncome = 0;
    _totalExpense = 0;

    for (var item in _movements) {
      final change = (item['change'] as num?)?.toInt() ?? 0;
      final type = item['type'] ?? '';

      if (type == 'Приход') {
        _totalIncome += change;
      } else if (type == 'Расход') {
        _totalExpense += change;
      }
    }

    _totalStockChange = _totalIncome - _totalExpense;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Аналитика: ${widget.product['name']}'),
        backgroundColor: Colors.orange[700],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _buildDateFilter(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _loadAllTimeData,
            tooltip: 'Показать все данные',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Нет данных за выбранный период',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Период: ${_formatDate(_selectedDateRange.start)} - ${_formatDate(_selectedDateRange.end)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllTimeData,
              icon: const Icon(Icons.history),
              label: const Text('Показать все данные'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информационная карточка
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      'Приход',
                      '$_totalIncome',
                      Colors.green,
                      Icons.arrow_downward,
                    ),
                    _buildStatCard(
                      'Расход',
                      '$_totalExpense',
                      Colors.red,
                      Icons.arrow_upward,
                    ),
                    _buildStatCard(
                      'Итого',
                      '${_totalStockChange >= 0 ? '+' : ''}$_totalStockChange',
                      _totalStockChange >= 0 ? Colors.green : Colors.red,
                      Icons.trending_up,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Заголовок графика
            Text(
              'Сравнение приходов и расходов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Период: ${_formatDate(_selectedDateRange.start)} - ${_formatDate(_selectedDateRange.end)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Столбчатая диаграмма
            SizedBox(
              height: 400,
              child: BarChart(
                _buildBarChartData(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  BarChartData _buildBarChartData() {
    final Map<String, Map<String, int>> dailyData = {};

    for (var item in _movements) {
      final date = item['date'] ?? '';
      final type = item['type'] ?? '';
      final change = (item['change'] as num?)?.toInt() ?? 0;

      if (!dailyData.containsKey(date)) {
        dailyData[date] = {'Приход': 0, 'Расход': 0};
      }

      if (type == 'Приход') {
        dailyData[date]!['Приход'] = (dailyData[date]!['Приход'] ?? 0) + change;
      } else if (type == 'Расход') {
        dailyData[date]!['Расход'] = (dailyData[date]!['Расход'] ?? 0) + change;
      }
    }

    final dates = dailyData.keys.toList()..sort();

    if (dates.isEmpty) {
      return BarChartData(
        minY: 0,
        maxY: 0,
        barGroups: [],
      );
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final income = dailyData[date]!['Приход'] ?? 0;
      final expense = dailyData[date]!['Расход'] ?? 0;

      final rods = <BarChartRodData>[];

      if (income > 0) {
        rods.add(
          BarChartRodData(
            toY: income.toDouble(),
            color: Colors.green,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }

      if (expense > 0) {
        rods.add(
          BarChartRodData(
            toY: -expense.toDouble(),
            color: Colors.red,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }

      if (rods.isNotEmpty) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: rods,
            barsSpace: 8,
          ),
        );
      }
    }

    final maxValue = dailyData.values.fold<int>(
      0,
          (max, day) => max > (day['Приход'] ?? 0) ? max : (day['Приход'] ?? 0),
    );
    final minValue = dailyData.values.fold<int>(
      0,
          (min, day) => min < (day['Расход'] ?? 0) ? min : (day['Расход'] ?? 0),
    );

    // Находим максимальное абсолютное значение для симметричной сетки
    final maxAbsValue = maxValue > minValue ? maxValue : minValue;
    final maxY = (maxAbsValue + 10).toDouble();
    final minY = (-maxAbsValue - 10).toDouble();

    return BarChartData(
      maxY: maxY,
      minY: minY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: maxAbsValue / 5, // 5 горизонтальных линий
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[300]!,
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey[300]!,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < dates.length) {
                final dateStr = dates[index];
                final parts = dateStr.split('-');
                if (parts.length == 3) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${parts[2]}.${parts[1]}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().abs().toString(),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      barGroups: barGroups,
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange[50],
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectDateRange(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(_formatDate(_selectedDateRange.start)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _selectDateRange(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(_formatDate(_selectedDateRange.end)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadData();
    }
  }
}