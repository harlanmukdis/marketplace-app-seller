import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/support/support_ticket.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/support_repository.dart';
import '../../../../di/injector.dart';

sealed class SupportState {
  const SupportState();
}

final class SupportInProgress extends SupportState {
  const SupportInProgress();
}

final class SupportFailure extends SupportState {
  const SupportFailure(this.error);

  final DataError error;
}

final class SupportLoaded extends SupportState {
  const SupportLoaded(this.tickets, {this.isBusy = false});

  final List<SupportTicket> tickets;
  final bool isBusy;
}

/// The account's tickets, and opening a new one.
class SupportCubit extends Cubit<SupportState> {
  SupportCubit() : super(const SupportInProgress());

  static SupportCubit get(BuildContext context) => BlocProvider.of(context);

  final SupportRepository _support = injector<SupportRepository>();

  Future<void> load() async {
    if (isClosed) return;
    emit(const SupportInProgress());
    final result = await _support.getTickets();
    if (isClosed) return;
    emit(switch (result) {
      DataSuccess<List<SupportTicket>>(:final value) => SupportLoaded(value),
      DataFailed<List<SupportTicket>>(:final failure) => SupportFailure(failure),
      _ => const SupportLoaded(<SupportTicket>[]),
    });
  }

  /// Returns the new ticket id, or the failure. The active store is attached
  /// as context so admins see which shop the seller is writing about.
  Future<(int?, DataError?)> create({
    required String category,
    required String subject,
    required String description,
    int? relatedOrderId,
  }) async {
    final current = state;
    if (current is SupportLoaded) {
      emit(SupportLoaded(current.tickets, isBusy: true));
    }
    final result = await _support.createTicket(
      category: category,
      subject: subject,
      description: description,
      storeId: injector<AuthRepository>().activeStoreId,
      relatedOrderId: relatedOrderId,
    );
    if (isClosed) return (null, null);
    switch (result) {
      case DataSuccess<int>(:final value):
        await load();
        return (value, null);
      case DataFailed<int>(:final failure):
        if (current is SupportLoaded) emit(SupportLoaded(current.tickets));
        return (null, failure);
      default:
        await load();
        return (null, null);
    }
  }
}

sealed class TicketState {
  const TicketState();
}

final class TicketInProgress extends TicketState {
  const TicketInProgress();
}

final class TicketFailure extends TicketState {
  const TicketFailure(this.error);

  final DataError error;
}

final class TicketLoaded extends TicketState {
  const TicketLoaded(this.ticket, this.messages, {this.isSending = false});

  final SupportTicket ticket;
  final List<SupportTicketMessage> messages;
  final bool isSending;
}

/// One ticket's thread.
class TicketCubit extends Cubit<TicketState> {
  TicketCubit(this.ticketId) : super(const TicketInProgress());

  static TicketCubit get(BuildContext context) => BlocProvider.of(context);

  final int ticketId;
  final SupportRepository _support = injector<SupportRepository>();

  Future<void> load() async {
    if (isClosed) return;
    final results = await Future.wait<Object>(<Future<Object>>[
      _support.getTicket(ticketId),
      _support.getMessages(ticketId),
    ]);
    if (isClosed) return;
    final ticket = results[0] as DataState<SupportTicket>;
    final messages = results[1] as DataState<List<SupportTicketMessage>>;
    switch (ticket) {
      case DataSuccess<SupportTicket>(:final value):
        emit(TicketLoaded(
          value,
          messages is DataSuccess<List<SupportTicketMessage>>
              ? messages.value
              : const <SupportTicketMessage>[],
        ));
      case DataFailed<SupportTicket>(:final failure):
        emit(TicketFailure(failure));
      default:
        emit(const TicketFailure(DataError(
          code: 'TICKET_NOT_FOUND',
          message: 'Tiket tidak ditemukan.',
        )));
    }
  }

  Future<DataError?> reply(String message) async {
    final current = state;
    if (current is! TicketLoaded || message.trim().isEmpty) return null;
    emit(TicketLoaded(current.ticket, current.messages, isSending: true));
    final result = await _support.reply(ticketId, message: message.trim());
    if (isClosed) return null;
    if (result is DataFailed<List<SupportTicketMessage>>) {
      emit(TicketLoaded(current.ticket, current.messages));
      return result.failure;
    }
    // The first reply moves the ticket to in_progress, so re-read it too.
    await load();
    return null;
  }
}
