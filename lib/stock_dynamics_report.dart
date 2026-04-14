import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'dart:math';

class StockDynamicsReport extends StatefulWidget {
  final Map<String, dynamic> product;

  const StockDynamicsReport({super.key, required this.product});

  @override
  State<StockDynamicsReport> createState() => _StockDynamicsReportState();
}

class _StockDynamicsReportState extends State<StockDynamicsReport> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  List<Map<String, dynamic>> _stockHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStockHistory();
  }

  Future<void> _loadStockHistory() async {
    setState(() => _isLoading = true);

    try {
      final history = await DatabaseHelper().getStockHistory(
        productUuid: widget.product['uuid'],
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
      );
      setState(() {
        _stockHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Ошибка загрузки истории: $e');
    }
  }

  Future<void> _syncStockHistory() async {
    setState(() => _isLoading = true);

    try {
      await _insertTestData();

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Данные синхронизированы!')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка синхронизации: $e')),
      );
    }
  }

  Future<void> _insertTestData() async {
    final db = await DatabaseHelper().database;

    final existing = await db.query('stock_history',
        where: 'product_uuid = ?',
        whereArgs: [widget.product['uuid']]
    );

    if (existing.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Данные уже существуют'),
          content: Text('Найдено ${existing.length} записей. Добавить тестовые данные?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      await db.delete('stock_history',
          where: 'product_uuid = ?',
          whereArgs: [widget.product['uuid']]
      );
    }

    double baseStock = (widget.product['stock'] as num?)?.toDouble() ?? 100.0;

    for (int i = 30; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      double variation = (i * 0.5).toDouble();
      double sinus = sin(i / 5 * pi) * 15;
      double stockValue = (baseStock - variation + sinus);
      if (stockValue < 0) stockValue = 0;

      await db.insert('stock_history', {
        'product_uuid': widget.product['uuid'],
        'date': dateStr,
        'stock': stockValue,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    _loadStockHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Тестовые данные добавлены!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Динамика остатков'),
        backgroundColor: Colors.green[700],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _buildDateFilter(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stockHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 64, color: Colors.grey),
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
              onPressed: _insertTestData,
              icon: const Icon(Icons.add),
              label: const Text('Добавить тестовые данные'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
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
            // Информационные карточки (друг под другом)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Текущий остаток', '${_getCurrentStock().toStringAsFixed(0)} ${widget.product['unit']}', Colors.blue),
                    const Divider(height: 24),
                    _buildInfoRow('Средний остаток', '${_getAverageStock().toStringAsFixed(2)} ${widget.product['unit']}', Colors.green),
                    const Divider(height: 24),
                    _buildInfoRow('Изменение за период', _getChangePercent(), _getChangeColor()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Заголовок графика
            Text(
              'График изменения остатков',
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

            // Линейный график
            SizedBox(
              height: 300,
              child: LineChart(
                _buildLineChartData(),
              ),
            ),

            const SizedBox(height: 24),

            // Кнопка синхронизации под графиком
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncStockHistory,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Подтянуть данные из 1С'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  double _getCurrentStock() {
    if (_stockHistory.isEmpty) return 0;
    final lastStock = _stockHistory.last['stock'] as num?;
    return lastStock?.toDouble() ?? 0;
  }

  double _getAverageStock() {
    if (_stockHistory.isEmpty) return 0;
    double sum = 0;
    for (var item in _stockHistory) {
      final stock = (item['stock'] as num?)?.toDouble() ?? 0;
      sum += stock;
    }
    return sum / _stockHistory.length;
  }

  String _getChangePercent() {
    if (_stockHistory.length < 2) return '0%';
    final firstStock = (_stockHistory.first['stock'] as num?)?.toDouble() ?? 0;
    final lastStock = (_stockHistory.last['stock'] as num?)?.toDouble() ?? 0;
    if (firstStock == 0) return '∞';
    final change = ((lastStock - firstStock) / firstStock * 100);
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }

  Color _getChangeColor() {
    if (_stockHistory.length < 2) return Colors.grey;
    final firstStock = (_stockHistory.first['stock'] as num?)?.toDouble() ?? 0;
    final lastStock = (_stockHistory.last['stock'] as num?)?.toDouble() ?? 0;
    if (lastStock >= firstStock) return Colors.green;
    return Colors.red;
  }

  LineChartData _buildLineChartData() {
    final spots = <FlSpot>[];
    for (int i = 0; i < _stockHistory.length; i++) {
      final item = _stockHistory[i];
      final stock = (item['stock'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), stock));
    }

    if (spots.isEmpty) {
      return LineChartData(
        gridData: const FlGridData(show: true),
        lineBarsData: [],
      );
    }

    final maxStock = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minStock = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    final range = maxStock - minStock;
    final horizontalInterval = range == 0 ? 1.0 : range / 5;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: horizontalInterval,
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < _stockHistory.length) {
                final dateStr = _stockHistory[index]['date'] ?? '';
                final parts = dateStr.split('-');
                if (parts.length == 3) {
                  return Text(
                    '${parts[2]}.${parts[1]}',
                    style: const TextStyle(fontSize: 10),
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
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
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
      borderData: FlBorderData(show: true),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
      ],
      minY: minStock > 0 ? minStock - (minStock * 0.1) : 0,
      maxY: maxStock + (maxStock * 0.1),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.green[50],
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
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: _loadStockHistory,
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
      _loadStockHistory();
    }
  }
}