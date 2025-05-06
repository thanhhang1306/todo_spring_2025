import 'dart:async';
import 'dart:math';

import '../data/todo.dart';
import 'filter/filter_sheet.dart';
import 'dashboard/dashboard_screen.dart';
import 'details/detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Para formatar data/hora

// --- Definindo a classe de tema aqui para simplicidade ---
// (Idealmente, mova para um ficheiro separado ou para main.dart)
abstract class RetroTheme {
  static const Color background = Color(0xFF1A1A2E);
  static const Color panel = Color(0xFF16213E);
  static const Color accent = Color(0xFFE43F5A);

  static const Color surface = Color(0xFF2F3A68);
  static const Color surfaceHighlight = Color(0xFF4A5B9E);
  static const Color primary = Color(0xFF00ffff);
  static const Color text = Color(0xFFf0f0f0);
  static const Color textSecondary = Color(0xFFa0a0a0);
  static const Color textDark = Color(0xFF000000);
  static const Color completed = Color(0xFF777777);

  static Color priorityHigh = Colors.red.shade400;
  static Color priorityMedium = Colors.orange.shade400;
  static Color priorityLow = Colors.green.shade400;

  static Color labelWork = Colors.blue.shade300;
  static Color labelPersonal = Colors.green.shade300;
  static Color labelUrgent = Colors.red.shade300;
  static Color labelShopping = Colors.purple.shade300;
  static Color labelDefault = Colors.grey.shade400;

  // Função auxiliar para pegar a cor da prioridade
  static Color getPriorityColor(String priority) {
    if (priority == 'high') return priorityHigh;
    if (priority == 'medium') return priorityMedium;
    return priorityLow;
  }

  // Função auxiliar para pegar a cor da label
  static Color getLabelColor(String lbl) {
    switch (lbl) {
      case 'Work': return labelWork;
      case 'Personal': return labelPersonal;
      case 'Urgent': return labelUrgent;
      case 'Shopping': return labelShopping;
      default: return labelDefault;
    }
  }
}

/// Main screen with List and Calendar views, plus a FAB to add todos.
class HomeScreen extends StatefulWidget {
  // Use const constructor
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Custom Painter permanece o mesmo
class _PixelBackgroundPainter extends CustomPainter {
  final List<Offset> stars;
  _PixelBackgroundPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1) deep-space fill
    paint.color = const Color(0xFF000010); // Fundo ainda mais escuro para o painter
    canvas.drawRect(Offset.zero & size, paint);

    // 2) tiny 2×2 stars
    paint.color = RetroTheme.textSecondary.withOpacity(0.7); // Estrelas com cor do tema
    for (final s in stars) {
      canvas.drawRect(
        Rect.fromLTWH(s.dx * size.width, s.dy * size.height, 2, 2),
        paint,
      );
    }

    // 3) pixel-DeathStar
    paint.color = RetroTheme.panel.withOpacity(0.8); // DeathStar com cor do tema
    const block = 8.0;
    final cx = size.width * 0.75;
    final cy = size.height * 0.25;
    const R = 80;
    for (var x = -R; x <= R; x += block.toInt()) {
      for (var y = -R; y <= R; y += block.toInt()) {
        if (x * x + y * y <= R * R) {
          canvas.drawRect(Rect.fromLTWH(cx + x, cy + y, block, block), paint);
        }
      }
    }

    // 4) pixel-ground tiles (Removido para simplicidade, pode adicionar de volta se quiser)
    // paint.color = const Color(0xFF111111);
    // final tile = 16.0;
    // final cols = (size.width / tile).ceil();
    // for (var i = 0; i < cols; i++) {
    //   canvas.drawRect(
    //     Rect.fromLTWH(i * tile, size.height - tile, tile, tile),
    //     paint,
    //   );
    // }
  }

  @override
  bool shouldRepaint(covariant _PixelBackgroundPainter old) => false; // Não precisa redesenhar constantemente
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Controllers and subscriptions
  final _searchController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSubscription;
  late final TabController _tabController;
  String _statusFilter = 'all'; // 'all' | 'active' | 'completed'
  bool _isSelectionMode = false;

  // Data
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos; // Lista que será exibida
  Set<String> _selectedTodoIds = {}; // IDs selecionados
  // late final TextStyle pixel; // Não é mais necessário, usar Theme.of(context).textTheme

  // Filter state
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date', // Campo usado para ordenação ('date', 'completion')
    order: 'descending', // Ordem ('ascending', 'descending')
    priority: 'all', // Prioridade ('all', 'low', 'medium', 'high')
    startDate: null, // Data de início para filtro de prazo
    endDate: null, // Data de fim para filtro de prazo
    labels: const [], // Lista de labels selecionadas para filtro
  );

  // Calendar-mode state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Para o background painter
  final List<Offset> _pixelStars = List.generate(
    150, // Aumentar número de estrelas
        (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  // Referência ao Firestore e Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user; // Usuário logado


  @override
  void initState() {
    super.initState();
    // pixel = GoogleFonts.pressStart2p( // Obter do tema agora
    //   color: Colors.white,
    //   fontSize: 12,
    // );
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {})); // Atualiza state na mudança de tab

    _user = _auth.currentUser;
    if (_user != null) {
      _subscribeToTodos();
    } else {
      // Idealmente, o RouterScreen lida com isso, mas como fallback:
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Implementar lógica de logout ou redirecionamento se necessário
      });
    }
  }

  // Configura o listener do Firestore
  void _subscribeToTodos() {
    if (_user == null) return;
    _todoSubscription?.cancel(); // Cancela subscrição anterior se houver

    // Query base ordenada por data de criação
    Query query = _firestore
        .collection('todos') // Assumindo que a coleção é 'todos' globalmente
        .where('uid', isEqualTo: _user!.uid); // Filtra pelo UID do usuário

    // Adiciona ordenação base (pode ser sobrescrita pelos filtros)
    query = query.orderBy('createdAt', descending: true);

    _todoSubscription = query
        .snapshots()
        .map((snap) => snap.docs.map((d) => Todo.fromSnapshot(d)).toList())
        .listen((todos) {
      setState(() {
        _todos = todos; // Atualiza a lista base
        _filteredTodos = _applyFilters(); // Aplica filtros à lista base
      });
    }, onError: (error) {
      print("Erro ao ouvir todos: $error");
      // Mostrar uma mensagem de erro para o usuário seria bom aqui
      setState(() {
        _todos = [];
        _filteredTodos = [];
      });
    });
  }


  @override
  void dispose() {
    _searchController.dispose();
    _todoSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Aplica todos os filtros (busca, status, prioridade, labels, data, ordenação)
  List<Todo> _applyFilters() {
    // Começa com a lista base de todos
    List<Todo> list = List.from(_todos);

    // 1. Filtro de Texto (Busca)
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      list = list.where((t) =>
      t.text.toLowerCase().contains(searchTerm) ||
          t.description.toLowerCase().contains(searchTerm) // Busca na descrição também
      ).toList();
    }

    // 2. Filtro de Status ('all', 'active', 'completed')
    if (_statusFilter == 'active') {
      list = list.where((t) => t.completedAt == null).toList();
    } else if (_statusFilter == 'completed') {
      list = list.where((t) => t.completedAt != null).toList();
    }

    // 3. Filtro de Prioridade
    if (_filters.priority != 'all') {
      list = list.where((t) => t.priority == _filters.priority).toList();
    }

    // 4. Filtro de Labels (verifica se ALGUMA label do filtro está presente no todo)
    if (_filters.labels.isNotEmpty) {
      list = list.where((t) =>
          t.labels.any((todoLabel) => _filters.labels.contains(todoLabel))
      ).toList();
    }

    // 5. Filtro de Data de Vencimento (Due Date)
    if (_filters.startDate != null) {
      list = list.where((t) => t.dueAt != null &&
          !t.dueAt!.isBefore(_filters.startDate!)).toList();
    }
    if (_filters.endDate != null) {
      // Adiciona 1 dia ao endDate para incluir todos os eventos DAQUELE dia
      final inclusiveEndDate = _filters.endDate!.add(const Duration(days: 1));
      list = list.where((t) => t.dueAt != null &&
          t.dueAt!.isBefore(inclusiveEndDate)).toList();
    }

    // 6. Ordenação
    list.sort((a, b) {
      int comparison;
      if (_filters.sortBy == 'date') {
        // Ordena por data de criação (ou prazo, se preferir - ajuste aqui)
        comparison = a.createdAt.compareTo(b.createdAt);
      } else { // 'completion'
        // Ordena por data de conclusão (nulos primeiro ou último dependendo da ordem)
        final completedA = a.completedAt;
        final completedB = b.completedAt;
        if (completedA == null && completedB == null) comparison = 0;
        else if (completedA == null) comparison = _filters.order == 'ascending' ? -1 : 1; // Nulos primeiro na ascendente
        else if (completedB == null) comparison = _filters.order == 'ascending' ? 1 : -1; // Nulos primeiro na ascendente
        else comparison = completedA.compareTo(completedB);
      }
      // Inverte se a ordem for descendente
      return _filters.order == 'ascending' ? comparison : -comparison;
    });

    return list;
  }

  /// Retorna todos para um dia específico (usado pelo calendário)
  List<Todo> _getEventsForDay(DateTime day) {
    // Usa a lista JÁ FILTRADA por status ('all', 'active', 'completed')
    return (_filteredTodos ?? []).where((todo) {
      if (todo.dueAt == null) return false; // Precisa ter prazo
      // Compara apenas ano, mês e dia
      return isSameDay(todo.dueAt!, day);
    }).toList();
  }

  /// Abre o formulário para adicionar/editar um Todo
  Future<void> _openTodoForm({Todo? todoToEdit}) async {
    // Preenche data inicial se estiver na tab Calendário e um dia selecionado
    DateTime? initialDate;
    if (todoToEdit == null && _tabController.index == 1 && _selectedDay != null) {
      final d = _selectedDay!;
      initialDate = DateTime(d.year, d.month, d.day); // Meia-noite do dia selecionado
    } else {
      initialDate = todoToEdit?.dueAt; // Usa data existente se editando
    }

    // Navega para a tela do formulário
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TodoFormScreen(
        initialDate: initialDate,
        todoToEdit: todoToEdit, // Passa o todo para edição
      )),
    );

    // Se o form retornou 'true' (salvou algo), re-aplicar filtros pode ser redundante
    // devido ao StreamBuilder, mas garantimos a atualização visual imediata.
    if (result == true) {
      // setState(() => _filteredTodos = _applyFilters()); // O StreamBuilder deve atualizar
    }
  }

  /// Deleta todos os Todos selecionados em modo de seleção
  Future<void> _deleteSelected() async {
    if (_selectedTodoIds.isEmpty || _user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panel,
        title: Text('Confirm deletion', style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: RetroTheme.accent)),
        content: Text('Do you really want to delete the ${_selectedTodoIds.length} selected items?', style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: RetroTheme.textSecondary),
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('todos'); // Ajuste se a coleção for diferente

      for (final id in _selectedTodoIds) {
        batch.delete(collectionRef.doc(id));
      }

      try {
        await batch.commit();
        setState(() {
          _selectedTodoIds.clear();
          _isSelectionMode = false; // Sai do modo de seleção após excluir
          // _filteredTodos = _applyFilters(); // StreamBuilder atualiza
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_selectedTodoIds.length} items deleted.', style: Theme.of(context).textTheme.bodySmall), backgroundColor: RetroTheme.accent)
        );
      } catch (e) {
        print("Batch delete error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting items.', style: Theme.of(context).textTheme.bodySmall), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  /// Alterna o status de completude de um Todo
  Future<void> _toggleComplete(Todo todo) async {
    if (_user == null) return;
    try {
      await _firestore
          .collection('todos') // Ajuste se a coleção for diferente
          .doc(todo.id)
          .update({
        'completedAt': todo.completedAt == null
            ? Timestamp.now() // Marca como completo agora
            : null, // Marca como incompleto
      });
      // StreamBuilder atualiza a UI
    } catch (e) {
      print("Error updating to-do status: $e");
      // Mostrar erro ao usuário
    }
  }

  // --- Funções Auxiliares de UI ---

  /// Constrói o widget para cada item da lista (usado em ambas as tabs)
  Widget _buildTodoItem(Todo todo) {
    final textTheme = Theme.of(context).textTheme;
    final bool isCompleted = todo.completedAt != null;
    final bool isSelected = _selectedTodoIds.contains(todo.id);

    return InkWell(
      // Long press ativa/desativa modo de seleção ou adiciona/remove item
      onLongPress: () {
        setState(() {
          if (!_isSelectionMode) {
            _isSelectionMode = true;
            _selectedTodoIds.add(todo.id);
          } else {
            // Se já estiver em modo de seleção, long press não faz nada
            // ou poderia ter outra ação, como abrir menu de contexto
          }
        });
      },
      // Tap navega para detalhes ou seleciona/desseleciona no modo de seleção
      onTap: () {
        setState(() {
          if (_isSelectionMode) {
            if (isSelected) {
              _selectedTodoIds.remove(todo.id);
              // Se não houver mais itens selecionados, sai do modo de seleção
              if (_selectedTodoIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedTodoIds.add(todo.id);
            }
          } else {
            // Navega para detalhes (ou abre form para editar)
            // Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(todo: todo)));
            _openTodoForm(todoToEdit: todo); // Abrir form para edição
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Margem
        padding: const EdgeInsets.all(10.0), // Padding interno
        decoration: BoxDecoration(
          color: isSelected ? RetroTheme.surfaceHighlight : RetroTheme.surface, // Cor de fundo
          border: Border.all( // Borda
              color: isSelected ? RetroTheme.accent : RetroTheme.primary,
              width: 2),
          borderRadius: BorderRadius.zero, // Cantos retos
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinha topo
          children: [
            // --- Leading: Checkbox de Seleção ou Prioridade/Checkbox de Completude ---
            Padding(
              padding: const EdgeInsets.only(right: 10.0, top: 2), // Espaço à direita
              child: _isSelectionMode
                  ? SizedBox( // Garante tamanho consistente
                width: 24, height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) { // onTap já trata a lógica de seleção
                    setState(() {
                      if (value == true) {
                        _selectedTodoIds.add(todo.id);
                      } else {
                        _selectedTodoIds.remove(todo.id);
                        if (_selectedTodoIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      }
                    });
                  },
                  // Estilo vem do CheckboxTheme
                ),
              )
                  : SizedBox( // Garante tamanho consistente
                width: 24, height: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prioridade (opcional, pode remover se não gostar)
                    // Container(
                    //   width: 10, height: 10,
                    //   decoration: BoxDecoration(
                    //     color: RetroTheme.getPriorityColor(todo.priority),
                    //     // shape: BoxShape.circle, // Ou quadrado
                    //     border: Border.all(color: RetroTheme.text.withOpacity(0.5))
                    //   ),
                    //   margin: EdgeInsets.only(right: 6),
                    // ),
                    // Checkbox de Completude
                    SizedBox(
                      width: 24, height: 24, // Tamanho explícito
                      child: Checkbox(
                        value: isCompleted,
                        onChanged: (v) => _toggleComplete(todo),
                        // Estilo vem do CheckboxTheme
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Conteúdo Principal: Título, Descrição, Labels ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    todo.text,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 11, // Um pouco maior para título
                      color: isCompleted ? RetroTheme.completed : RetroTheme.getPriorityColor(todo.priority), // Cor pela prioridade
                      decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: RetroTheme.accent, // Cor do risco
                      decorationThickness: 2,
                    ),
                    maxLines: 2, // Evita que textos muito longos quebrem o layout
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Descrição (se houver)
                  if (todo.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      todo.description,
                      style: textTheme.bodySmall?.copyWith(color: RetroTheme.textSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Data de Vencimento (Due Date) (se houver)
                  if (todo.dueAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 7, color: RetroTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yy HH:mm').format(todo.dueAt!), // Formato pt-BR
                          style: textTheme.bodySmall?.copyWith(fontSize: 5, color: RetroTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],

                  // Labels (se houver)
                  if (todo.labels.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4, // Espaço horizontal entre chips
                      runSpacing: 2, // Espaço vertical entre linhas de chips
                      children: todo.labels.map((lbl) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: RetroTheme.getLabelColor(lbl).withOpacity(0.8), // Cor da label com opacidade
                          borderRadius: BorderRadius.zero, // Quadrado
                          border: Border.all(color: RetroTheme.getLabelColor(lbl), width:1),
                        ),
                        child: Text(
                          lbl.toUpperCase(), // Nomes em maiúsculas para estilo
                          style: textTheme.labelSmall?.copyWith(
                            color: RetroTheme.textDark, // Texto escuro sobre cor da label
                            fontSize: 7,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // --- Trailing: Ícone de Navegação (apenas se não estiver em modo de seleção) ---
            if (!_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: RetroTheme.primary.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Obtém o tema e textTheme atuais
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Stack(
      children: [
        // 1) Background Painter
        CustomPaint(
          size: MediaQuery.of(context).size, // Ocupa tela inteira
          painter: _PixelBackgroundPainter(_pixelStars),
        ),

        // 2) Scaffold Transparente
        Scaffold(
          backgroundColor: Colors.transparent, // Essencial para ver o painter
          appBar: AppBar(
            // Estilo vem do AppBarTheme
            // backgroundColor: RetroTheme.panel,
            title: Text('DARTHUB', style: textTheme.titleLarge), // Usar estilo do tema
            bottom: TabBar(
              controller: _tabController,
              // Estilo vem do TabBarTheme
              tabs: const [
                Tab(text: 'TASKS'), // Texto em maiúsculas
                Tab(text: 'CALENDAR'),
              ],
            ),
            actions: [
              // Ações mudam se estiver em modo de seleção
              if (_isSelectionMode) ...[
                // Contador de Selecionados
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                        '${_selectedTodoIds.length}',
                        style: textTheme.bodyMedium?.copyWith(color: RetroTheme.accent, fontSize: 14)
                    ),
                  ),
                ),
                // Botão Excluir Selecionados
                IconButton(
                  icon: const Icon(Icons.delete_sweep), // Ícone diferente
                  tooltip: 'Excluir selecionados',
                  color: RetroTheme.accent, // Cor de destaque para excluir
                  onPressed: _deleteSelected,
                ),
                // Botão Cancelar Seleção
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancelar seleção',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedTodoIds.clear();
                    });
                  },
                ),
              ] else ...[
                // Botão Dashboard
                IconButton(
                  icon: const Icon(Icons.dashboard_customize_outlined), // Ícone diferente
                  tooltip: 'Dashboard',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DashboardScreen(todos: _todos)), // Passa todos para dashboard
                    );
                  },
                ),
                // Botão Ativar Modo de Seleção
                IconButton(
                  icon: const Icon(Icons.check_box_outlined), // Ícone diferente
                  tooltip: 'Selecionar itens',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedTodoIds.clear(); // Limpa seleção ao entrar no modo
                    });
                  },
                ),
                // Botão Filtro de Status (Archive)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.archive_outlined), // Ícone diferente
                  tooltip: 'Show To-Dos',
                  color: RetroTheme.panel, // Fundo do menu
                  // Estilo do item vem do PopupMenuTheme
                  onSelected: (value) {
                    setState(() {
                      _statusFilter = value;
                      _filteredTodos = _applyFilters(); // Re-aplica filtros
                    });
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'all', child: Text('All', style: textTheme.bodySmall)),
                    PopupMenuItem(value: 'active', child: Text('Active', style: textTheme.bodySmall)),
                    PopupMenuItem(value: 'completed', child: Text('Completed', style: textTheme.bodySmall)),
                  ],
                ),
              ],
            ],
          ),
          floatingActionButton: FloatingActionButton(
            // Estilo vem do FloatingActionButtonTheme
            onPressed: _openTodoForm, // Abre form para ADICIONAR
            tooltip: 'Add To-Do',
            child: const Icon(Icons.add),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // --- View: Lista de Tarefas ---
              _buildListView(theme, textTheme),

              // --- View: Calendário ---
              _buildCalendarView(theme, textTheme),
            ],
          ),
        )
      ],
    );
  }

  /// Constrói a view da Lista de Tarefas
  Widget _buildListView(ThemeData theme, TextTheme textTheme) {
    return Column(
      children: [
        // --- Campo de Busca e Botão de Filtro ---
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            style: textTheme.bodyMedium?.copyWith(fontSize: 11), // Estilo do texto digitado
            decoration: InputDecoration(
              // Estilo geral vem do InputTheme
              hintText: 'Search To-Do', // Usar hintText em vez de labelText
              prefixIcon: const Icon(Icons.search, size: 18), // Ícone de busca
              suffixIcon: IconButton( // Botão para abrir filtros avançados
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                tooltip: 'Advanced Filters',
                onPressed: () async {
                  final result = await showModalBottomSheet<FilterSheetResult>(
                    context: context,
                    backgroundColor: RetroTheme.panel, // Fundo do sheet
                    builder: (_) => FilterSheet(initialFilters: _filters),
                  );
                  if (result != null) {
                    setState(() {
                      _filters = result; // Atualiza os filtros
                      _filteredTodos = _applyFilters(); // Re-aplica
                    });
                  }
                },
              ),
            ),
            onChanged: (_) => setState(() => _filteredTodos = _applyFilters()), // Atualiza busca dinamicamente
          ),
        ),
        // --- Lista de Tarefas ---
        Expanded(
          child: (_filteredTodos == null) // Verifica se ainda está carregando
              ? const Center(child: CircularProgressIndicator(color: RetroTheme.accent))
              : (_filteredTodos!.isEmpty) // Verifica se a lista filtrada está vazia
              ? Center(child: Text('No to-do found!', style: textTheme.bodyMedium))
              : ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB não cobrir o último item
            itemCount: _filteredTodos!.length,
            itemBuilder: (ctx, i) {
              final todo = _filteredTodos![i];
              return _buildTodoItem(todo); // Usa a função de construção do item
            },
          ),
        ),
      ],
    );
  }

  /// Constrói a view do Calendário
  Widget _buildCalendarView(ThemeData theme, TextTheme textTheme) {
    return Column(
      children: [
        // --- Widget TableCalendar ---
        TableCalendar<Todo>(
          // Dias
          firstDay: DateTime.utc(2010, 1, 1), // Ajuste conforme necessário
          lastDay: DateTime.utc(2040, 12, 31),
          focusedDay: _focusedDay,
          // Seleção
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) { // Só atualiza se for diferente
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; // Atualiza foco ao selecionar
              });
            }
          },
          // Formato
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const { // Formatos disponíveis
            CalendarFormat.month: 'Month', // Textos em português
            CalendarFormat.week: 'Week',
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() => _calendarFormat = format);
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay; // Atualiza foco ao mudar página
          },
          // Eventos (tarefas com prazo)
          eventLoader: _getEventsForDay, // Função que busca eventos para o dia

          // --- Estilização do Calendário ---
          calendarStyle: CalendarStyle(
            // Dias normais
            defaultTextStyle: textTheme.bodySmall!.copyWith(fontSize: 9, color: RetroTheme.text),
            weekendTextStyle: textTheme.bodySmall!.copyWith(fontSize: 9, color: RetroTheme.primary), // Fim de semana em Cyan
            outsideTextStyle: textTheme.bodySmall!.copyWith(fontSize: 9, color: RetroTheme.textSecondary.withOpacity(0.5)), // Dias fora do mês
            // Dia selecionado
            selectedTextStyle: textTheme.bodySmall!.copyWith(fontSize: 9, color: RetroTheme.textDark),
            selectedDecoration: const BoxDecoration(color: RetroTheme.accent, shape: BoxShape.rectangle), // Retângulo accent
            // Dia atual (hoje)
            todayTextStyle: textTheme.bodySmall!.copyWith(fontSize: 9, color: RetroTheme.textDark),
            todayDecoration: BoxDecoration(color: RetroTheme.primary.withOpacity(0.7), shape: BoxShape.rectangle), // Retângulo Cyan semi-transparente
            // Marcadores de evento
            markerDecoration: BoxDecoration( // Marcador padrão (se não usar builder)
              color: RetroTheme.accent.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            markersMaxCount: 1, // Mostrar apenas um marcador genérico
            markerSize: 5.0,
            markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
            canMarkersOverflow: false, // Evita que marcadores saiam da célula
          ),
          headerStyle: HeaderStyle(
            titleTextStyle: textTheme.bodyMedium!.copyWith(color: RetroTheme.accent, fontSize: 14), // Título (Mês/Ano)
            formatButtonTextStyle: textTheme.bodySmall!.copyWith(color: RetroTheme.text),
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: RetroTheme.primary, width: 1),
              // borderRadius: BorderRadius.zero, // Não suportado diretamente
            ),
            leftChevronIcon: const Icon(Icons.chevron_left, color: RetroTheme.primary, size: 18),
            rightChevronIcon: const Icon(Icons.chevron_right, color: RetroTheme.primary, size: 18),
            formatButtonVisible: true, // Mostra botão Mês/Semana
            titleCentered: true, // Centraliza título
            formatButtonShowsNext: false, // Texto do botão não muda
          ),
          daysOfWeekStyle: DaysOfWeekStyle( // Estilo dos dias da semana (Seg, Ter, ...)
            weekdayStyle: textTheme.bodySmall!.copyWith(fontSize: 8, color: RetroTheme.textSecondary),
            weekendStyle: textTheme.bodySmall!.copyWith(fontSize: 8, color: RetroTheme.primary), // Fim de semana em Cyan
          ),
          // --- Marcador de Evento Personalizado (Opcional, sobrepõe markerDecoration) ---
          // calendarBuilders: CalendarBuilders<Todo>(
          //   markerBuilder: (context, date, events) {
          //     if (events.isNotEmpty) {
          //       // Pega a maior prioridade entre os eventos do dia
          //       final priorities = events.map((e) => e.priority).toList();
          //       final color = priorities.contains('high') ? RetroTheme.priorityHigh :
          //                     priorities.contains('medium') ? RetroTheme.priorityMedium :
          //                     RetroTheme.priorityLow;
          //       return Positioned( // Posiciona o marcador
          //         right: 1,
          //         bottom: 1,
          //         child: Container(
          //           width: 7, height: 7,
          //           decoration: BoxDecoration(shape: BoxShape.rectangle, color: color), // Quadrado com cor da prioridade
          //         ),
          //       );
          //     }
          //     return null;
          //   },
          // ),
        ),

        const Divider(color: RetroTheme.primary, height: 1, thickness: 1), // Linha divisória

        // --- Lista de Tarefas para o Dia Selecionado ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Text(
            'To-Dos for: ${DateFormat('MM/dd/yyyy').format(_selectedDay ?? _focusedDay)}', // Mostra data selecionada
            style: textTheme.bodyMedium?.copyWith(color: RetroTheme.accent),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final todosDoDia = _getEventsForDay(_selectedDay ?? _focusedDay); // Pega eventos do dia
              if (todosDoDia.isEmpty) {
                return Center(child: Text('No to-do for this day..', style: textTheme.bodyMedium));
              }
              // Usa o mesmo ListView.builder da outra tab
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80), // Espaço para FAB
                itemCount: todosDoDia.length,
                itemBuilder: (ctx, i) {
                  final todo = todosDoDia[i];
                  return _buildTodoItem(todo); // Reutiliza a função de construção do item
                },
              );
            },
          ),
        ),
      ],
    );
  }

} // Fim de _HomeScreenState


// --- Tela de Formulário (TodoFormScreen) ---
// (Movida para fora da classe _HomeScreenState para melhor organização)

class TodoFormScreen extends StatefulWidget {
  final DateTime? initialDate; // Data inicial pré-selecionada (do calendário)
  final Todo? todoToEdit; // Todo existente para edição (opcional)

  const TodoFormScreen({super.key, this.initialDate, this.todoToEdit});

  @override
  State<TodoFormScreen> createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  // Controllers para os campos de texto
  final _textController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Estado do formulário
  String _priority = 'low'; // Prioridade padrão
  DateTime? _dueDate; // Data/Hora de vencimento
  final List<String> _allLabels = ['Work', 'Personal', 'Urgent', 'Shopping', 'Study', 'Other']; // Lista de labels disponíveis
  Set<String> _selectedLabels = {}; // Labels selecionadas para este Todo

  bool _isSaving = false; // Para indicar estado de salvamento

  @override
  void initState() {
    super.initState();

    // Preenche o formulário se estiver editando um Todo existente
    if (widget.todoToEdit != null) {
      final todo = widget.todoToEdit!;
      _textController.text = todo.text;
      _descriptionController.text = todo.description;
      _priority = todo.priority;
      _dueDate = todo.dueAt;
      _selectedLabels = Set.from(todo.labels); // Converte lista para Set
    } else {
      // Se não estiver editando, usa a data inicial (se houver)
      _dueDate = widget.initialDate;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Mostra DatePicker e depois TimePicker para selecionar data e hora de vencimento
  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final initialDatePickerDate = _dueDate ?? now;

    // 1. Escolher Data
    final date = await showDatePicker(
      context: context,
      initialDate: initialDatePickerDate,
      firstDate: DateTime(now.year - 1), // Permite selecionar datas no passado recente
      lastDate: DateTime(now.year + 10), // Permite selecionar datas futuras
      builder: (context, child) { // Aplicar tema ao DatePicker
        return Theme(
          data: Theme.of(context).copyWith( // Copia tema atual e ajusta cores
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: RetroTheme.accent, // Cor principal do picker
                onPrimary: RetroTheme.textDark, // Texto sobre a cor principal
                surface: RetroTheme.panel, // Fundo do picker
                onSurface: RetroTheme.text, // Texto sobre o fundo
              ),
              dialogBackgroundColor: RetroTheme.background, // Fundo fora do picker
              textTheme: Theme.of(context).textTheme.copyWith( // Garante a fonte correta
                  bodyMedium: GoogleFonts.pressStart2p(fontSize: 4),
                  labelSmall: GoogleFonts.pressStart2p(fontSize: 4)
              )
          ),
          child: child!,
        );
      },
    );
    if (date == null) return; // Usuário cancelou

    // 2. Escolher Hora
    final initialTime = _dueDate != null ? TimeOfDay.fromDateTime(_dueDate!) : TimeOfDay.now();
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) { // Aplicar tema ao TimePicker
        return Theme(
          data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: RetroTheme.accent,
                onPrimary: RetroTheme.textDark,
                surface: RetroTheme.panel,
                onSurface: RetroTheme.text,
              ),
              dialogBackgroundColor: RetroTheme.background,
              timePickerTheme: TimePickerThemeData( // Estilos específicos do TimePicker
                backgroundColor: RetroTheme.panel,
                hourMinuteShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Quadrado
                dayPeriodShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Quadrado
                hourMinuteColor: RetroTheme.surface,
                hourMinuteTextColor: RetroTheme.text,
                dayPeriodColor: RetroTheme.surface,
                dayPeriodTextColor: RetroTheme.text,
                dialBackgroundColor: RetroTheme.surface,
                dialHandColor: RetroTheme.accent,
                dialTextColor: RetroTheme.text,
                entryModeIconColor: RetroTheme.primary,
                helpTextStyle: GoogleFonts.pressStart2p(fontSize: 4, color: RetroTheme.textSecondary),
              ),
              textTheme: Theme.of(context).textTheme.copyWith( // Garante a fonte correta
                  bodyMedium: GoogleFonts.pressStart2p(fontSize: 4),
                  labelSmall: GoogleFonts.pressStart2p(fontSize: 4)
              )
          ),
          child: child!,
        );
      },
    );

    // Combina data e hora (ou só data se a hora for cancelada)
    setState(() {
      if (time == null) { // Se cancelou hora, usa meia-noite
        _dueDate = DateTime(date.year, date.month, date.day);
      } else {
        _dueDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    });
  }

  /// Salva o Todo (cria um novo ou atualiza um existente)
  Future<void> _saveTodo() async {
    final user = FirebaseAuth.instance.currentUser;
    // Validação básica: precisa de texto e usuário logado
    if (user == null || _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('The To-Do title cannot be empty!', style: Theme.of(context).textTheme.bodySmall), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _isSaving = true); // Ativa indicador de progresso

    // Monta os dados do Todo
    final todoData = {
      'text': _textController.text.trim(),
      'description': _descriptionController.text.trim(),
      'uid': user.uid, // Associa ao usuário logado
      'priority': _priority,
      'dueAt': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null, // Converte para Timestamp do Firestore
      'labels': _selectedLabels.toList(), // Converte Set para List
      // Campos de controle: createdAt e completedAt
      // Se editando, não sobrescreve completedAt, a menos que a lógica permita
      // Se criando, completedAt é null e createdAt é definido pelo servidor
    };

    try {
      if (widget.todoToEdit != null) {
        // --- Atualizando Todo Existente ---
        // Mantém completedAt original, a menos que a edição o altere (não é o caso aqui)
        // Mantém createdAt original
        await FirebaseFirestore.instance
            .collection('todos') // Ajuste coleção se necessário
            .doc(widget.todoToEdit!.id)
            .update(todoData); // Atualiza com os novos dados
      } else {
        // --- Criando Novo Todo ---
        todoData['createdAt'] = FieldValue.serverTimestamp(); // Firestore define a data de criação
        todoData['completedAt'] = null; // Novo todo nunca está completo
        await FirebaseFirestore.instance
            .collection('todos') // Ajuste coleção se necessário
            .add(todoData); // Adiciona novo documento
      }
      // Fecha o formulário e retorna 'true' para indicar sucesso
      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      print("Error saving to-do: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving to-do: $e', style: Theme.of(context).textTheme.bodySmall), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      // Garante que o estado de salvamento é desativado, mesmo se houver erro
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Formata o texto da data/hora de vencimento para exibição
    final String dueText;
    if (_dueDate == null) {
      dueText = 'None';
    } else {
      dueText = DateFormat('MM/dd/yy HH:mm').format(_dueDate!);
    }

    return Scaffold(
      backgroundColor: RetroTheme.background, // Fundo da tela de form
      appBar: AppBar(
        // Estilo do AppBar vem do tema
        title: Text(
            widget.todoToEdit == null ? 'New To-Do' : 'Edit To-Do',
            style: textTheme.titleLarge?.copyWith(fontSize: 16) // Título menor no form
        ),
        leading: IconButton( // Botão de voltar customizado
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.maybePop(context), // Tenta voltar
          tooltip: 'Back',
        ),
      ),
      body: Column(
        children: [
          // --- Campos do Formulário (Roláveis) ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Título ---
                  TextField(
                    controller: _textController,
                    style: textTheme.bodyMedium, // Estilo do texto digitado
                    decoration: const InputDecoration(
                      // Estilo vem do InputTheme
                      labelText: 'To-Do *', // Indica campo obrigatório
                    ),
                    textInputAction: TextInputAction.next, // Vai para próximo campo com Enter
                  ),
                  const SizedBox(height: 16),

                  // --- Descrição ---
                  TextField(
                    controller: _descriptionController,
                    style: textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      // hintText: 'Adicione mais detalhes...' // Opcional
                    ),
                    maxLines: 3, // Permite múltiplas linhas
                    textInputAction: TextInputAction.done, // Finaliza digitação
                  ),
                  const SizedBox(height: 20),

                  // --- Prioridade ---
                  Row(
                    children: [
                      Text('Priority:', style: textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      // Dropdown estilizado
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: RetroTheme.panel, // Cor de fundo do dropdown aberto
                        ),
                        child: DropdownButton<String>(
                          value: _priority,
                          icon: const Icon(Icons.arrow_drop_down, color: RetroTheme.primary),
                          style: textTheme.bodyMedium?.copyWith(color: RetroTheme.getPriorityColor(_priority)), // Cor do texto muda com a prioridade
                          underline: Container(height: 1, color: RetroTheme.primary), // Linha customizada
                          items: ['low', 'medium', 'high'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value[0].toUpperCase() + value.substring(1), // Low, Medium, High
                                style: textTheme.bodyMedium?.copyWith(color: RetroTheme.getPriorityColor(value)),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _priority = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- Data e Hora de Vencimento ---
                  ListTile( // Usar ListTile para layout fácil
                    contentPadding: EdgeInsets.zero, // Remover padding padrão
                    leading: const Icon(Icons.calendar_today_outlined, color: RetroTheme.primary, size: 18),
                    title: Text('Deadline: $dueText', style: textTheme.bodyMedium),
                    trailing: (_dueDate != null) // Botão para limpar data
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: RetroTheme.accent, size: 18),
                      tooltip: 'Clear Deadline',
                      onPressed: () => setState(() => _dueDate = null),
                    )
                        : null, // Sem botão se não houver data
                    onTap: _pickDueDateTime, // Abre o seletor de data/hora
                  ),
                  const SizedBox(height: 16),

                  // --- Labels ---
                  Text('Labels:', style: textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, // Espaçamento horizontal
                    runSpacing: 4, // Espaçamento vertical
                    children: _allLabels.map((label) => FilterChip(
                      // Estilo vem do ChipTheme, mas podemos ajustar aqui
                      label: Text(label, style: GoogleFonts.pressStart2p(
                        fontSize: 9,
                        color: _selectedLabels.contains(label) ? RetroTheme.textDark : RetroTheme.textSecondary, // Cor do texto muda se selecionado
                      )),
                      selected: _selectedLabels.contains(label),
                      onSelected: (isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selectedLabels.add(label);
                          } else {
                            _selectedLabels.remove(label);
                          }
                        });
                      },
                      backgroundColor: RetroTheme.surface, // Cor de fundo não selecionado
                      selectedColor: RetroTheme.getLabelColor(label), // Cor de fundo selecionado
                      checkmarkColor: RetroTheme.textDark, // Cor do check (se visível)
                      side: BorderSide( // Borda
                        color: _selectedLabels.contains(label)
                            ? RetroTheme.accent // Borda accent se selecionado
                            : RetroTheme.primary.withOpacity(0.5), // Borda primária se não
                        width: _selectedLabels.contains(label) ? 2 : 1,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Quadrado
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

          // --- Botão Salvar (Fixo na parte inferior) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Padding inferior maior
            child: SizedBox(
              width: double.infinity, // Ocupa largura total
              height: 48,
              child: ElevatedButton.icon(
                // Estilo vem do ElevatedButtonTheme
                icon: _isSaving
                    ? Container( // Indicador de progresso pequeno
                    width: 16, height: 16,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: RetroTheme.textDark))
                    : const Icon(Icons.save, size: 18), // Ícone de salvar
                label: Text(_isSaving ? 'Saving...' : 'Save'),
                onPressed: _isSaving ? null : _saveTodo, // Desabilita botão enquanto salva
              ),
            ),
          ),
        ],
      ),
    );
  }
}