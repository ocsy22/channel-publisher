import 'package:flutter_test/flutter_test.dart';
import 'package:channel_publisher/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChannelPublisherApp());
    expect(find.byType(ChannelPublisherApp), findsOneWidget);
  });
}
