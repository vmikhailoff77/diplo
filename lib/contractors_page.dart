import 'package:flutter/material.dart';
import 'database_helper.dart';

class ContractorsPage extends StatefulWidget {
  const ContractorsPage({super.key});

  @override
  State<ContractorsPage> createState() => _ContractorsPageState();
}

class _ContractorsPageState extends State<ContractorsPage> {
  List<Map<String, dynamic>> _contractors = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContractors();
  }

  Future<void> _loadContractors() async {
    setState(() => _isLoading = true);
    final contractors = await DatabaseHelper().getContractors();
    setState(() {
      _contractors = contractors;
      _isLoading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      await _loadContractors();
      return;
    }
    setState(() => _isLoading = true);
    final results = await DatabaseHelper().searchContractors(query);
    setState(() {
      _contractors = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контрагенты'),
        backgroundColor: Colors.orange[700],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по наименованию...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadContractors();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _search,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contractors.isEmpty
          ? const Center(child: Text('Нет данных'))
          : ListView.builder(
        itemCount: _contractors.length,
        itemBuilder: (context, index) {
          final contractor = _contractors[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: Text('${index + 1}'),
              ),
              title: Text(contractor['name'] ?? 'Без имени'),
              subtitle: contractor['cod'] != null && contractor['cod'].isNotEmpty
                  ? Text('Код: ${contractor['cod']}')
                  : null,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(contractor['name'] ?? 'Контрагент'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Код', contractor['cod']),
                        _buildDetailRow('UUID', contractor['uuid']?.substring(0, 8) ?? '—'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Закрыть'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value ?? '—')),
        ],
      ),
    );
  }
}