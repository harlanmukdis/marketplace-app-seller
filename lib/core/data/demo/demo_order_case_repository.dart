import '../../data_state.dart';
import '../../domain/model/order/order_case.dart';
import '../../domain/repositories/order_case_repository.dart';
import 'demo_support.dart';

/// Sample cases for S-18 / S-19. Decisions are kept in memory for the
/// session, so the flow can be walked through; nothing reaches the server.
class DemoOrderCaseRepository implements OrderCaseRepository {
  DemoOrderCaseRepository();

  static const String _cancelFeature = 'Permintaan pembatalan';
  static const String _complaintFeature = 'Komplain & retur';

  final DateTime _t0 = DateTime.now();

  late final Map<int, CancellationRequest> _cancellations =
      <int, CancellationRequest>{
    for (final c in <CancellationRequest>[
      CancellationRequest(
        id: 7101,
        orderNumber: 'XP2501182765',
        buyerName: 'D****** (Pembeli)',
        reason: 'Ingin mengubah alamat pengiriman / salah pilih varian warna',
        buyerNote: 'Mohon maaf min, salah klik varian warna hitam harusnya '
            'warna putih, mau re-order ulang.',
        requestedAt: _t0.subtract(const Duration(hours: 5, minutes: 30)),
        respondBy: _t0.add(const Duration(hours: 18, minutes: 30)),
        orderStage: 'Menunggu Handover',
        courier: 'JNE Regular',
        awb: 'XP2501234567890',
        items: const <CaseItem>[
          CaseItem(
              name: 'Kopi Arabika Gayo 250g', variant: 'Biji', price: 75000),
          CaseItem(
              name: 'Gula Aren Cair 500ml',
              variant: 'Original',
              quantity: 2,
              price: 25000),
        ],
        isSample: true,
      ),
      CancellationRequest(
        id: 7102,
        orderNumber: 'XP2501190021',
        buyerName: 'M***** (Pembeli)',
        reason: 'Menemukan harga lebih murah di toko lain',
        requestedAt: _t0.subtract(const Duration(hours: 1)),
        respondBy: _t0.add(const Duration(hours: 23)),
        orderStage: 'Processing',
        courier: 'SiCepat REG',
        awb: 'SCP8812003941',
        items: const <CaseItem>[
          CaseItem(name: 'Keripik Singkong Balado 250g', price: 22000),
        ],
        isSample: true,
      ),
    ])
      c.id: c,
  };

  late final Map<int, Complaint> _complaints = <int, Complaint>{
    for (final c in <Complaint>[
      Complaint(
        id: 8801,
        number: 'CMP-20250118-88',
        orderNumber: 'XP2501129941',
        issue: 'Barang Rusak / Malfungsi saat Diterima',
        requestedSolution: 'Retur Barang & Refund',
        amount: 75000,
        item: const CaseItem(
            name: 'Kopi Arabika Gayo 250g', variant: 'Biji', price: 75000),
        buyerName: 'A****** K****',
        buyerCity: 'Kota Surabaya',
        buyerNote: 'Kemasan penyok dan segelnya sobek, biji kopi tumpah '
            'sebagian di dalam kardus.',
        evidence: const <CaseEvidence>[
          CaseEvidence(label: '00:42 Unboxing', isVideo: true),
          CaseEvidence(label: 'Foto Kerusakan'),
          CaseEvidence(label: 'Label Paket'),
        ],
        awb: 'XP2501234500001',
        receivedAt: _t0.subtract(const Duration(days: 1, hours: 3)),
        respondBy: _t0.add(const Duration(hours: 32, minutes: 15)),
        isSample: true,
      ),
    ])
      c.id: c,
  };

  @override
  Future<DataState<List<CancellationRequest>>> getCancellationRequests(
          int storeId) =>
      demoOr(_cancelFeature, () => _cancellations.values.toList());

  @override
  Future<DataState<List<Complaint>>> getComplaints(int storeId) =>
      demoOr(_complaintFeature, () => _complaints.values.toList());

  @override
  Future<DataState<CancellationRequest>> getCancellationRequest(int id) =>
      demoOr(_cancelFeature, () => _cancellations[id]!);

  @override
  Future<DataState<Complaint>> getComplaint(int id) =>
      demoOr(_complaintFeature, () => _complaints[id]!);

  @override
  Future<DataError?> respondCancellation(
    int id, {
    required bool approve,
    String? rejectReason,
  }) async {
    final error = await demoWrite(_cancelFeature);
    if (error != null) return error;
    final c = _cancellations[id];
    if (c == null || !c.isPending) {
      return const DataError(
        code: DataErrorCode.invalidState,
        message: 'Permintaan ini sudah diputuskan.',
      );
    }
    if (!approve && (rejectReason == null || rejectReason.isEmpty)) {
      return const DataError(
        code: DataErrorCode.validationError,
        message: 'Pilih alasan penolakan.',
      );
    }
    _cancellations[id] = c.decided(
      approve ? CaseStatus.approved : CaseStatus.rejected,
      rejectReason: rejectReason,
    );
    return null;
  }

  @override
  Future<DataError?> resolveComplaint(
      int id, ComplaintResolution resolution) async {
    final error = await demoWrite(_complaintFeature);
    if (error != null) return error;
    final c = _complaints[id];
    if (c == null || !c.isPending) {
      return const DataError(
        code: DataErrorCode.invalidState,
        message: 'Komplain ini sudah diputuskan.',
      );
    }
    _complaints[id] = c.resolved(resolution);
    return null;
  }
}
