import 'package:flutter_test/flutter_test.dart';

import 'package:rental_mobil/main.dart';

void main() {
  testWidgets('Rental app shows home content', (WidgetTester tester) async {
    await tester.pumpWidget(const RentalMobilApp());

    expect(find.text('Timbang Mlaku Transportation'), findsOneWidget);
    expect(find.text('Booking Mobil Sekarang'), findsOneWidget);
    expect(find.text('Kenapa pilih kami'), findsOneWidget);
  });
}
