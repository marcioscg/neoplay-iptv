import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'items_screen.dart';

/// Tela 12 — Busca global em canais e filmes.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = state.search(_query);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar canais e filmes',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _controller.clear();
                _query = '';
              }),
            ),
        ],
      ),
      body: _query.trim().length < 2
          ? const EmptyState(
              icon: Icons.search,
              title: 'Digite ao menos 2 letras',
              message:
                  'A busca cobre canais ao vivo e conteúdo sob demanda da lista ativa.',
            )
          : results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off, title: 'Nenhum resultado')
              : Column(
                  children: [
                    SectionLabel('${results.length} resultado(s)'),
                    Expanded(child: ItemsList(items: results)),
                  ],
                ),
    );
  }
}
