import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'router/router_screen.dart'; // Importa a RouterScreen
import 'package:timezone/data/latest.dart' as tz;

// Definição das cores retro
abstract class RetroColors {
  static const Color background = Color(0xFF1a1a2e); // Azul muito escuro
  static const Color surface = Color(0xFF4a4e69);   // Roxo/Cinza suave
  static const Color primary = Color(0xFF00ffff);   // Cyan brilhante (Accent)
  static const Color text = Color(0xFFf0f0f0);      // Branco suave
  static const Color textDark = Color(0xFF2d2d2d);    // Cinza escuro para texto sobre fundos claros
  static const Color accent = Color(0xFFff00ff);    // Magenta brilhante
  static const Color completed = Color(0xFF9a9a9a); // Cinza para texto concluído
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro ToDo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'PressStart2P', // Define a fonte padrão
        brightness: Brightness.dark, // Define um tema escuro como base
        scaffoldBackgroundColor: RetroColors.background, // Cor de fundo padrão
        primaryColor: RetroColors.primary, // Cor primária (pode ser usada em AppBars, etc.)

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: RetroColors.surface, // Cor da AppBar
          foregroundColor: RetroColors.text, // Cor do título e ícones na AppBar
          elevation: 0, // Sem sombra para um look mais flat
          titleTextStyle: TextStyle(
            fontFamily: 'PressStart2P',
            color: RetroColors.text,
            fontSize: 16, // Ajuste o tamanho conforme necessário
          ),
          iconTheme: IconThemeData(
            color: RetroColors.primary, // Cor dos ícones na AppBar
          ),
        ),

        // FloatingActionButton Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: RetroColors.accent, // Cor do FAB
          foregroundColor: RetroColors.textDark, // Cor do ícone dentro do FAB
          elevation: 0,
          shape: BeveledRectangleBorder(), // Canto "cortado" para estilo retro
          // Para um botão quadrado:
          // shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),

        // Checkbox Theme
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return RetroColors.primary; // Cor quando selecionado
            }
            return RetroColors.surface; // Cor quando não selecionado
          }),
          checkColor: MaterialStateProperty.all(RetroColors.textDark), // Cor do 'check'
          side: const BorderSide(color: RetroColors.primary, width: 2), // Borda da checkbox
          shape: const BeveledRectangleBorder(), // Canto "cortado"
          // Para um quadrado:
          // shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),

        // Input Decoration Theme (para TextFields)
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: RetroColors.surface, // Fundo do TextField
          hintStyle: TextStyle(color: RetroColors.text, fontSize: 10), // Estilo do hint text
          labelStyle: TextStyle(color: RetroColors.text, fontSize: 10), // Estilo do label text
          enabledBorder: OutlineInputBorder( // Borda quando não focado
            borderSide: BorderSide(color: RetroColors.primary, width: 2),
            borderRadius: BorderRadius.zero, // Cantos retos
          ),
          focusedBorder: OutlineInputBorder( // Borda quando focado
            borderSide: BorderSide(color: RetroColors.accent, width: 2),
            borderRadius: BorderRadius.zero, // Cantos retos
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), // Padding interno
        ),

        // Text Theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: RetroColors.text, fontSize: 12),
          bodyMedium: TextStyle(color: RetroColors.text, fontSize: 10), // Tamanho padrão do texto
          titleLarge: TextStyle(color: RetroColors.text, fontSize: 16), // Ex: Título da AppBar
          labelSmall: TextStyle(color: RetroColors.text, fontSize: 8),
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: RetroColors.primary, // Cor padrão para ícones
        ),

        // ElevatedButton Theme (se usar)
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: RetroColors.primary,
                foregroundColor: RetroColors.textDark,
                elevation: 0,
                shape: const BeveledRectangleBorder(), // Canto "cortado"
                // Para um quadrado:
                // shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                textStyle: const TextStyle(fontFamily: 'PressStart2P')
            )
        ),

        // TextButton Theme (se usar)
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: RetroColors.primary,
                textStyle: const TextStyle(fontFamily: 'PressStart2P')
            )
        ),

        // Define o colorScheme para consistência
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: RetroColors.primary,
          onPrimary: RetroColors.textDark, // Texto/icones sobre cor primária
          secondary: RetroColors.accent,
          onSecondary: RetroColors.textDark, // Texto/icones sobre cor secundária
          error: Colors.redAccent,
          onError: RetroColors.text,
          background: RetroColors.background,
          onBackground: RetroColors.text, // Texto/icones sobre cor de fundo
          surface: RetroColors.surface,
          onSurface: RetroColors.text, // Texto/icones sobre cor de superfície
        ),
      ),
      home: const RouterScreen(), // O seu ponto de entrada
    );
  }
}