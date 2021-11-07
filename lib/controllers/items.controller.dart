import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:trackitem/controllers/auth.controller.dart';
import 'package:trackitem/models/item.model.dart';
import 'package:trackitem/repositories/custom.exception.dart';
import 'package:trackitem/repositories/item.repo.dart';

enum ItemListFilter {
  all,
  obtained,
}

final itemListFilterProvider =
    StateProvider<ItemListFilter>((_) => ItemListFilter.all);

final filteredItemListProvider = Provider<List<Item>>((ref) {
  final itemListFilterState = ref.watch(itemListFilterProvider);
  final itemListState = ref.watch(itemListControllerProvider);

  return itemListState.maybeWhen(
      data: (items) {
        switch (itemListFilterState.state) {
          case ItemListFilter.obtained:
            return items.where((element) => element.obtained).toList();
          default:
            return items;
        }
      },
      orElse: () => []);
});

final itemListExceptionProvider = StateProvider<CustomException?>((_) => null);

final itemListControllerProvider =
    StateNotifierProvider<ItemListController, AsyncValue<List<Item>>>((ref) {
  final user = ref.watch(authControllerProvider);
  return ItemListController(ref.read, user?.uid);
});

class ItemListController extends StateNotifier<AsyncValue<List<Item>>> {
  final Reader _reader;
  final String? _userId;

  ItemListController(this._reader, this._userId)
      : super(const AsyncValue.loading()) {
    if (_userId != null) {
      retrieveItems();
    }
  }

  Future<void> retrieveItems({bool isRefreshing = false}) async {
    if (isRefreshing) state = AsyncValue.loading();
    try {
      final items =
          await _reader(itemRepositoryProvider).retrieveItems(userId: _userId!);
      if (mounted) {
        state = AsyncValue.data(items);
      }
    } on CustomException catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem({required String name, bool obtained = false}) async {
    try {
      final item = Item(name: name, obtained: obtained);
      final itemId = await _reader(itemRepositoryProvider)
          .createItem(userId: _userId!, item: item);

      state.whenData((items) =>
          state = AsyncValue.data(items..add(item.copyWith(id: itemId))));
    } on CustomException catch (e) {
      _reader(itemListExceptionProvider).state = e;
    }
  }

  Future<void> updateItem({required Item updatedItem}) async {
    try {
      await _reader(itemRepositoryProvider)
          .updateItem(userId: _userId!, item: updatedItem);
      state.whenData((items) {
        state = AsyncValue.data([
          for (final item in items)
            if (item.id == updatedItem.id) updatedItem else item
        ]);
      });
    } on CustomException catch (e) {
      _reader(itemListExceptionProvider).state = e;
    }
  }

  Future<void> deleteItem({required String itemId}) async {
    try {
      await _reader(itemRepositoryProvider).deleteItem(
        userId: _userId!,
        itemId: itemId,
      );
      state.whenData((items) => state =
          AsyncValue.data(items..removeWhere((item) => item.id == itemId)));
    } on CustomException catch (e) {
      _reader(itemListExceptionProvider).state = e;
    }
  }
}
