import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Necessário para Todo.fromSnapshot se usado
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/todo.dart'; // Importa a classe Todo
// Importar o tema se precisar das cores diretamente (ou usar Theme.of(context))
// import '../home_screen.dart'; // Se RetroTheme estiver lá
// import '../../main.dart'; // Se RetroColors/RetroTheme estiver lá
// import '../../theme/retro_theme.dart'; // Se RetroTheme estiver em ficheiro próprio

/// Modelo de dados para as estatísticas (pode manter ou calcular diretamente no build)
class TodoStats {
  final int total;
  final int completed;
  double get completionRate => total == 0 ? 0 : completed / total;

  TodoStats({required this.total, required this.completed});

  // Factory para calcular a partir da lista de Todos
  factory TodoStats.fromTodoList(List<Todo> todos) {
    final completedCount = todos.where((t) => t.completedAt != null).length;
    return TodoStats(total: todos.length, completed: completedCount);
  }
}

/// Modelo de dados para os milestones (pode manter ou calcular diretamente no build)
class Milestone {
  final int threshold;
  final String description; // Adicionar descrição para clareza
  final bool achieved;

  Milestone({required this.threshold, required this.description, required this.achieved});
}

/// Dashboard screen showing overall stats, profile info, and unlocked milestones.
/// Modificado para ser StatelessWidget e receber a lista de todos.
class DashboardScreen extends StatelessWidget {
  // 1. Variável final para receber a lista de todos
  final List<Todo> todos;

  // Lista estática de thresholds para milestones
  static const List<Map<String, dynamic>> _milestoneData = [
    {'threshold': 1, 'description': 'First Task Completed!'},
    {'threshold': 5, 'description': 'Five Tasks Done!'},
    {'threshold': 10, 'description': 'Ten Tasks Completed!'},
    {'threshold': 25, 'description': '25 Tasks Milestone!'},
    {'threshold': 50, 'description': 'Half-Century of Tasks!'},
    {'threshold': 100, 'description': '100 Tasks Completed! WOW!'},
  ];

  // 2. Construtor modificado para requerer 'todos'
  const DashboardScreen({
    required this.todos, // Parâmetro obrigatório
    Key? key,
  }) : super(key: key);

  // 3. Função auxiliar (agora estática ou dentro do build) para construir milestones
  List<Milestone> _buildMilestones(int completedCount) {
    return _milestoneData
        .map((data) => Milestone(
      threshold: data['threshold'] as int,
      description: data['description'] as String,
      achieved: completedCount >= (data['threshold'] as int),
    ))
        .toList();
  }

  // 4. Função auxiliar (movida para fora ou chamada diretamente no onPressed)
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // Navega para a primeira rota (provavelmente LoginScreen via RouterScreen)
    // e remove todas as outras rotas da pilha.
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 5. Calcula as estatísticas diretamente da lista 'todos' recebida
    final stats = TodoStats.fromTodoList(todos);
    final milestones = _buildMilestones(stats.completed);
    final user = FirebaseAuth.instance.currentUser; // Pega o usuário atual

    // Acessar o tema para cores e fontes
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // Acessar cores customizadas se necessário (ex: se RetroTheme/RetroColors estiver em main.dart)
    // final retroColors = RetroColors; // Se estiver definido em main.dart ou ficheiro próprio

    return Scaffold(
      // Usar AppBarTheme do tema principal
      appBar: AppBar(
        title: const Text('Dashboard'), // Estilo virá do tema
        leading: IconButton( // Adicionar botão de voltar explícito
          icon: const Icon(Icons.arrow_back_ios, size: 18), // Usar IconTheme
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Voltar',
        ),
      ),
      body: SafeArea(
        // Não precisa mais do FutureBuilder, pois os dados já foram passados
        child: ListView( // Usar ListView para permitir scroll se o conteúdo for grande
          padding: const EdgeInsets.all(16),
          children: [
            // --- Profile Card ---
            if (user != null)
              Card(
                color: theme.colorScheme.surface.withOpacity(0.8), // Cor do card
                shape: RoundedRectangleBorder( // Bordas retas para estilo retro
                    borderRadius: BorderRadius.zero,
                    side: BorderSide(color: theme.colorScheme.primary, width: 1)
                ),
                margin: const EdgeInsets.only(bottom: 24),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary, // Cor do avatar
                    foregroundColor: theme.colorScheme.onPrimary, // Cor do texto/ícone no avatar
                    child: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName![0].toUpperCase() // Primeira letra do nome Display
                          : user.email?.isNotEmpty == true
                          ? user.email![0].toUpperCase() // Ou primeira letra do email
                          : '?', // Fallback
                      style: textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ),
                  title: Text(
                      user.displayName ?? user.email ?? 'Usuário Anônimo', // Mostrar nome ou email
                      style: textTheme.bodyMedium?.copyWith(fontSize: 11)
                  ),
                  // subtitle: Text(user.email ?? '', style: textTheme.bodySmall), // Pode adicionar email como subtítulo
                  trailing: IconButton(
                    icon: const Icon(Icons.logout), // Ícone de logout (cor do IconTheme)
                    tooltip: 'Sair',
                    onPressed: () => _signOut(context), // Chama a função signOut
                  ),
                ),
              ),

            // --- Summary Cards Row ---
            Row(
              children: [
                Expanded(
                  child: _StatCard( // Usar o widget auxiliar _StatCard
                    label: 'Total Tasks',
                    value: stats.total.toString(),
                    icon: Icons.list_alt_outlined, // Ícone outline
                  ),
                ),
                const SizedBox(width: 12), // Espaçamento menor
                Expanded(
                  child: _StatCard(
                    label: 'Completed',
                    value: stats.completed.toString(),
                    icon: Icons.check_circle_outline, // Ícone outline
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Completion Indicator ---
            Text('Completion Rate', style: textTheme.bodyLarge?.copyWith(fontSize: 12)), // Título da seção
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.completionRate,
              backgroundColor: theme.colorScheme.surface, // Cor de fundo da barra
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary), // Cor da barra (Cyan)
              minHeight: 8, // Altura da barra
            ),
            const SizedBox(height: 6),
            Align( // Alinha o texto à direita
              alignment: Alignment.centerRight,
              child: Text(
                  '${(stats.completionRate * 100).toStringAsFixed(0)}%', // Percentagem sem casas decimais
                  style: textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)
              ),
            ),
            const SizedBox(height: 24),

            // --- Milestones Section ---
            Text('Milestones', style: textTheme.bodyLarge?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            // Gera a lista de milestones
            if (milestones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Complete tasks to unlock milestones!", style: textTheme.bodyMedium),
              )
            else
              ...milestones.map( // Usa spread operator (...) para adicionar widgets à lista
                    (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile( // Usar ListTile para layout simples
                    dense: true, // Torna o ListTile mais compacto
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      m.achieved ? Icons.star : Icons.star_border, // Ícone de estrela
                      size: 20,
                      color: m.achieved ? Colors.amber.shade300 : theme.iconTheme.color?.withOpacity(0.5), // Cor da estrela
                    ),
                    title: Text(
                        m.description, // Descrição do milestone
                        style: textTheme.bodyMedium?.copyWith(
                            color: m.achieved ? theme.textTheme.bodyMedium?.color : theme.textTheme.bodyMedium?.color?.withOpacity(0.6) // Esmaece se não alcançado
                        )
                    ),
                    // subtitle: Text('Reach ${m.threshold} completed tasks', style: textTheme.bodySmall), // Opcional
                  ),
                ),
              ),
            const SizedBox(height: 16), // Espaço no final
          ],
        ),
      ),
    );
  }
}

/// Widget reutilizável para os cartões de estatística
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      color: theme.colorScheme.surface.withOpacity(0.8), // Cor de fundo do cartão
      shape: RoundedRectangleBorder( // Bordas retas
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: theme.colorScheme.primary, width: 1) // Borda Cyan fina
      ),
      elevation: 0, // Sem sombra
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // Ajustar padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ocupa espaço mínimo vertical
          crossAxisAlignment: CrossAxisAlignment.center, // Centraliza horizontalmente
          children: [
            Icon(icon, size: 24, color: theme.iconTheme.color), // Ícone com cor do tema
            const SizedBox(height: 8),
            Text(
                value,
                style: textTheme.titleLarge?.copyWith( // Estilo para o valor numérico
                    color: theme.colorScheme.primary, // Valor em Cyan
                    fontSize: 18
                )
            ),
            const SizedBox(height: 2),
            Text(
                label,
                style: textTheme.bodySmall // Estilo para o rótulo
            ),
          ],
        ),
      ),
    );
  }
}