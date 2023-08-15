import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/entity.dart';

part 'tag_queue.g.dart';

@riverpod
class TagQueue extends _$TagQueue {
  @override
  Queue<Entity> build() {
    return Queue<Entity>();
  }

  void queue(Entity entity) {
    Queue<Entity> newQueue = Queue<Entity>();
    newQueue.add(entity);
    newQueue.addAll(state);
    state = newQueue;
  }
}
