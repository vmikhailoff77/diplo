import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'document_models.dart';

class DocumentsListPage extends StatefulWidget {
  final String title;
  final String endpoint;
  final Color color;

  const DocumentsListPage({
    super.key,
    required this.title,
    required this.endpoint,
    required this.color,
  });

  @override
  State<DocumentsListPage> createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends State<DocumentsListPage> {
  List<dynamic> _documents = [];
  bool _isLoading = true;
  String _error = '';

  final String baseUrl = 'http://192.168.1.217/flutter_order_1C/hs/flutter_1c';

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl${widget.endpoint}'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _documents = data;
          _isLoading = false;
        });
      } else {
        throw Exception('Ошибка: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDocuments,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDocuments,
              child: const Text('Повторить'),
            ),
          ],
        ),
      )
          : _documents.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Нет документов'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDocuments,
              child: const Text('Обновить'),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIcon(),
                  color: widget.color,
                ),
              ),
              title: Text(
                '№${doc['number']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Контрагент: ${doc['customer_name']}'),
                  Text('Дата: ${doc['date']?.toString().substring(0, 10) ?? ''}'),
                  if (doc['amount'] != null)
                    Text(
                      'Сумма: ${doc['amount']} ₽',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  if (doc['status'] != null)
                    Chip(
                      label: Text(doc['status']),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Переход на детали документа
                _showDetails(context, doc);
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon() {
    switch (widget.endpoint) {
      case '/orders':
        return Icons.shopping_cart;
      case '/sales':
        return Icons.local_shipping;
      case '/income':
        return Icons.arrow_downward;
      case '/expense':
        return Icons.arrow_upward;
      default:
        return Icons.description;
    }
  }

  void _showDetails(BuildContext context, Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Документ №${doc['number']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Номер:', doc['number']),
              _detailRow('Дата:', doc['date']?.toString().substring(0, 10) ?? ''),
              _detailRow('Контрагент:', doc['customer_name']),
              if (doc['amount'] != null) _detailRow('Сумма:', '${doc['amount']} ₽'),
              if (doc['status'] != null) _detailRow('Статус:', doc['status']),
              if (doc['uuid'] != null) _detailRow('UUID:', doc['uuid']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}