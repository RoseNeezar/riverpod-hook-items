import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:trackitem/controllers/auth.controller.dart';
import 'package:trackitem/controllers/items.controller.dart';
import 'package:trackitem/hook/addItemDialog.hook.dart';
import 'package:trackitem/models/item.model.dart';
import 'package:trackitem/repositories/custom.exception.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends HookWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authControllerState = useProvider(authControllerProvider);
    final itemListFilter = useProvider(itemListFilterProvider);
    final isObtainedFilter = itemListFilter.state == ItemListFilter.obtained;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        leading: authControllerState != null
            ? IconButton(
                onPressed: () =>
                    context.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              itemListFilter.state = isObtainedFilter
                  ? ItemListFilter.all
                  : ItemListFilter.obtained;
            },
            icon: Icon(isObtainedFilter
                ? Icons.check_circle
                : Icons.check_circle_outline),
          )
        ],
      ),
      body: ProviderListener(
        provider: itemListExceptionProvider,
        onChange: (BuildContext context,
            StateController<CustomException?> customException) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(customException.state!.message!),
            backgroundColor: Colors.red,
          ));
        },
        child: const ItemList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddItemDialog.show(context, Item.empty()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

final currentItem = ScopedProvider<Item>((_) => throw UnimplementedError());

class ItemList extends HookWidget {
  const ItemList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final itemListState = useProvider(itemListControllerProvider);
    final filteredItemList = useProvider(filteredItemListProvider);
    return itemListState.when(
      data: (items) => items.isEmpty
          ? const Center(
              child: Text(
                'Tap + to add item',
                style: TextStyle(
                  fontSize: 20.0,
                ),
              ),
            )
          : ListView.builder(
              itemCount: filteredItemList.length,
              itemBuilder: (BuildContext context, int index) {
                final item = filteredItemList[index];
                return ProviderScope(
                  overrides: [currentItem.overrideWithValue(item)],
                  child: const ItemTile(),
                );
              },
            ),
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => ItemListError(
        message:
            error is CustomException ? error.message! : 'Something went wrong',
      ),
    );
  }
}

class ItemTile extends HookWidget {
  const ItemTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final item = useProvider(currentItem);
    return ListTile(
      key: ValueKey(item.id),
      title: Text(item.name),
      trailing: Checkbox(
        value: item.obtained,
        onChanged: (val) =>
            context.read(itemListControllerProvider.notifier).updateItem(
                  updatedItem: item.copyWith(obtained: !item.obtained),
                ),
      ),
      onTap: () => AddItemDialog.show(context, item),
      onLongPress: () => context
          .read(itemListControllerProvider.notifier)
          .deleteItem(itemId: item.id!),
    );
  }
}

class ItemListError extends StatelessWidget {
  final String message;

  const ItemListError({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(fontSize: 20.0)),
          const SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () => context
                .read(itemListControllerProvider.notifier)
                .retrieveItems(isRefreshing: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
