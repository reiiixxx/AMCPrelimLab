import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/persona.dart';

final selectedPersonaProvider = StateProvider<Persona?>((ref) => null);