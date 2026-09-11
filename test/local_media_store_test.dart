import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/local/local_media_store.dart';

void main() {
  late Directory temp;
  late LocalMediaStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('i_glasset_test');
    store = LocalMediaStore(root: temp);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  final bytes = Uint8List.fromList(List.generate(64, (i) => i));
  final checksum = sha256.convert(bytes).toString();

  test('writes an image into the user-owned folder', () async {
    final file = await store.write(
      tastingId: 't1',
      itemId: 'i1',
      remotePath: 'tastings/t1/items/i1.jpg',
      bytes: bytes,
      expectedSha256: checksum,
    );

    expect(await file.exists(), isTrue);
    expect(file.path, contains('I Glasset/tastings/t1/items/i1.jpg'));
    expect(await file.readAsBytes(), bytes);
  });

  test('rejects bytes that do not match the advertised checksum', () async {
    await expectLater(
      store.write(
        tastingId: 't1',
        itemId: 'i1',
        remotePath: 'tastings/t1/items/i1.jpg',
        bytes: bytes,
        expectedSha256: 'a' * 64,
      ),
      throwsA(isA<MediaChecksumMismatch>()),
    );

    // and leaves nothing behind that `has()` would mistake for a cached image
    final present = await store.has(
      tastingId: 't1',
      itemId: 'i1',
      remotePath: 'tastings/t1/items/i1.jpg',
    );
    expect(present, isFalse);
  });

  test('has() reports false before a download and true after', () async {
    expect(
      await store.has(
        tastingId: 't1',
        itemId: 'i1',
        remotePath: 'tastings/t1/items/i1.png',
      ),
      isFalse,
    );

    await store.write(
      tastingId: 't1',
      itemId: 'i1',
      remotePath: 'tastings/t1/items/i1.png',
      bytes: bytes,
    );

    expect(
      await store.has(
        tastingId: 't1',
        itemId: 'i1',
        remotePath: 'tastings/t1/items/i1.png',
      ),
      isTrue,
    );
  });

  test('deleting a tasting reclaims its folder', () async {
    await store.write(
      tastingId: 't1',
      itemId: 'i1',
      remotePath: 'tastings/t1/items/i1.jpg',
      bytes: bytes,
    );
    expect(await store.usedBytes(), bytes.length);

    await store.deleteTasting('t1');
    expect(await store.usedBytes(), 0);
  });
}
