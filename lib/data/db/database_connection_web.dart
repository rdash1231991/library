import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Web database connection.
///
/// For "easy deployment" we use an **in-memory** sqlite database backed by
/// WebAssembly (no worker, no IndexedDB persistence).
///
/// This keeps Docker deployment simple and avoids `dart:ffi` (not available on web).
Future<QueryExecutor> openQueryExecutor() async {
  // This file must be available at runtime (served from `/sqlite3.wasm`).
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);

  return WasmDatabase.inMemory(sqlite3);
}

