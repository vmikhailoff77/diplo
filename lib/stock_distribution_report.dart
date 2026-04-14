import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';

class StockDistributionReport extends StatelessWidget {
  final Map<String, dynamic> product;

  const StockDistributionReport({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Распределение остатков'),
        backgroundColor: Colors.green[700],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getAllProductsWithStock(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!
              .where((p) {
            final stock = p['stock'];
            return stock != null && stock > 0;
          })
              .toList();

          if (products.isEmpty) {
            return const Center(child: Text('Нет товаров с остатками'));
          }

          final highlightedIndex = products.indexWhere(
                  (p) => p['uuid'] == product['uuid']
          );

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                  ),

                ),
                const SizedBox(height: 20),
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: _buildSections(products, highlightedIndex),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLegend(products, highlightedIndex),
              ],
            ),
          );
        },
      ),
    );
  }

  List<PieChartSectionData> _buildSections(List<Map<String, dynamic>> products, int highlightedIndex) {
    // Вычисляем общую сумму остатков (приводим всё к double)
    double totalStock = 0.0;
    for (var item in products) {
      dynamic stockValue = item['stock'];
      if (stockValue != null) {
        if (stockValue is int) {
          totalStock += stockValue.toDouble();
        } else if (stockValue is double) {
          totalStock += stockValue;
        } else if (stockValue is String) {
          totalStock += double.tryParse(stockValue) ?? 0.0;
        }
      }
    }

    // Защита от деления на ноль
    if (totalStock <= 0) {
      return [];
    }

    final List<PieChartSectionData> sections = [];

    for (int i = 0; i < products.length; i++) {
      final item = products[i];
      dynamic stockValue = item['stock'];

      double stock = 0.0;
      if (stockValue is int) {
        stock = stockValue.toDouble();
      } else if (stockValue is double) {
        stock = stockValue;
      } else if (stockValue is String) {
        stock = double.tryParse(stockValue) ?? 0.0;
      }

      final percentage = (stock / totalStock) * 100;
      final isHighlighted = i == highlightedIndex;

      sections.add(
        PieChartSectionData(
          value: stock,
          title: percentage > 8 ? '${percentage.toStringAsFixed(1)}%' : '',
          titleStyle: TextStyle(
            fontSize: isHighlighted ? 14 : 12,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
          radius: isHighlighted ? 120 : 100,
          color: isHighlighted ? Colors.orange : _getColor(i),
        ),
      );
    }

    return sections;
  }

  Widget _buildLegend(List<Map<String, dynamic>> products, int highlightedIndex) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(products.length, (index) {
            final item = products[index];
            final stock = item['stock'] ?? 0;
            final isHighlighted = index == highlightedIndex;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isHighlighted ? Colors.orange[50] : null,
                borderRadius: BorderRadius.circular(4),
                border: isHighlighted ? Border.all(color: Colors.orange) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isHighlighted ? Colors.orange : _getColor(index),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHighlighted ? '⭐ ${item['name']}' : item['name'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$stock ${item['unit'] ?? ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Color _getColor(int index) {
    final colors = [
      Colors.blue, Colors.green, Colors.red, Colors.purple,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo,
      Colors.cyan, Colors.lime, Colors.deepOrange, Colors.brown,
    ];
    return colors[index % colors.length];
  }
}