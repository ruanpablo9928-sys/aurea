import 'package:flutter/material.dart';

/// Navegador raiz usado por integracoes que nascem fora de um widget, como o
/// botao "Abrir editor" do Laboratorio.
final GlobalKey<NavigatorState> aureaNavigatorKey = GlobalKey<NavigatorState>();
