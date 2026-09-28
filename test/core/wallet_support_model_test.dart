import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/support/support_ticket.dart';
import 'package:navy_wear/core/domain/model/wallet/bank_account.dart';

/// Payloads captured from the running marketplace API (v1.28.0).
void main() {
  group('BankAccount.fromJson', () {
    test('reads a saved account and masks its number', () {
      final account = BankAccount.fromJson(<String, dynamic>{
        'id': '1',
        'user_id': '11',
        'bank_name': 'BCA',
        'account_number': '1234567890',
        'account_holder_name': 'probe seller',
        'created_at': '2026-09-28 22:13:31',
      });

      expect(account.id, 1);
      expect(account.bankName, 'BCA');
      expect(account.maskedNumber, '•••• 7890');
      // Stored as typed — the server compares case-insensitively.
      expect(account.holderName, 'probe seller');
    });
  });

  group('SupportTicket.fromJson', () {
    test('reads a ticket, whose first reply moved it to in_progress', () {
      final ticket = SupportTicket.fromJson(<String, dynamic>{
        'id': '1',
        'ticket_number': 'TIX-QQJN896PM3',
        'user_id': '11',
        'store_id': null,
        'related_order_id': null,
        'category': 'payment_wallet',
        'subject': 'Probe dari app seller',
        'description': 'Uji integrasi, abaikan.',
        'status': 'in_progress',
        'assigned_admin_id': null,
        'resolved_at': null,
        'created_at': '2026-09-28 22:13:31',
      });

      expect(ticket.ticketNumber, 'TIX-QQJN896PM3');
      expect(ticket.category, SupportCategory.paymentWallet);
      expect(ticket.isClosed, isFalse);
      expect(ticket.storeId, isNull);
      expect(SupportTicketStatus.label(ticket.status), 'Diproses');
    });

    test('reads a message, telling the seller from the team by a "0"/"1"', () {
      final mine = SupportTicketMessage.fromJson(<String, dynamic>{
        'id': '1',
        'ticket_id': '1',
        'sender_user_id': '11',
        'is_admin_reply': '0',
        'message': 'Balasan lewat form',
        'attachment_url': null,
        'created_at': '2026-09-28 22:13:31',
      });

      expect(mine.isAdminReply, isFalse);
      expect(mine.message, 'Balasan lewat form');
    });

    test('offers exactly the four categories the server accepts', () {
      expect(SupportCategory.all, hasLength(4));
      expect(SupportCategory.all.toSet(), <String>{
        'order_transaction',
        'account_security',
        'payment_wallet',
        'report_violation',
      });
    });
  });
}
