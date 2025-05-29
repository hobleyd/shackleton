import 'package:flutter/material.dart' hide Notification, NotificationListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/notification_listener.dart';
import '../models/notification.dart';
import '../providers/notify.dart';

class ShackletonNotifications extends ConsumerStatefulWidget {
  const ShackletonNotifications({super.key, });

  @override
  ConsumerState<ShackletonNotifications> createState() => _ShackletonNotifications();
}

class _ShackletonNotifications extends ConsumerState<ShackletonNotifications> with TickerProviderStateMixin implements NotificationListener {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    List<Notification> errors = ref.read(notifyProvider);

    return SlideTransition(
        position: _animation,
        child: _isVisible
        ? Container(
            color: Colors.grey[50],
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: ListView.builder(
                      itemCount: errors.length,
                      itemBuilder: (context, index) {
                        return Container(
                          color: errors[index].type == NotificationType.ERROR ? Colors.pink[50] : Colors.blue[50],
                          child: Text(
                            errors[index].message,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.left,
                          ),
                        );
                      },
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                    ),
                  ),
                ),
                Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 3),
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: ElevatedButton(
                    onPressed: () => ref.read(notifyProvider.notifier).clear(),
                    child: Text('Clear', style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
              ]),
            ),
          )
        : SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    ref.read(notifyProvider.notifier).addListener(this);

    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this,);
    _animation = Tween<Offset>(begin: Offset(1,0), end: Offset.zero,).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut,));
  }

  // There may well be a better way of doing this, but we want to animate this when we get a notification and this way,
  // the notifyProvider can call this to start the animation.
  @override
  void setNotificationVisibility({bool isVisible = false}) {
    setState(() {
      _isVisible = isVisible;
      if (mounted) {
        if (_isVisible) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      }
    });
  }
}
