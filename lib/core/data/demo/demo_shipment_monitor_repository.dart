import '../../data_state.dart';
import '../../domain/model/shipping/tracked_shipment.dart';
import '../../domain/repositories/shipment_monitor_repository.dart';
import 'demo_support.dart';

class DemoShipmentMonitorRepository implements ShipmentMonitorRepository {
  const DemoShipmentMonitorRepository();

  @override
  Future<DataState<List<TrackedShipment>>> getShipments(int storeId) {
    final now = DateTime.now();
    DateTime ago(int h, [int m = 0]) =>
        now.subtract(Duration(hours: h, minutes: m));
    return demoOr(
        'Monitoring pengiriman',
        () => <TrackedShipment>[
              TrackedShipment(
                awb: 'JNE12345678901',
                courier: 'JNE Regular',
                orderNumber: 'XP2501193321',
                state: ShipmentState.problem,
                destinationCity: 'Kota Bandung',
                buyerName: 'R***** M*****',
                checkpoints: <ShipmentCheckpoint>[
                  ShipmentCheckpoint(
                    location: 'Gudang Transit Sukajadi',
                    description: 'Alamat penerima tidak dapat dijangkau akibat '
                        'genangan air. Kurir menjadwalkan upaya ulang.',
                    at: ago(2),
                  ),
                  ShipmentCheckpoint(
                    location: 'Hub Bandung',
                    description: 'Paket tiba di hub kota tujuan.',
                    at: ago(20),
                  ),
                  ShipmentCheckpoint(
                    location: 'Drop Point Jakarta Barat',
                    description: 'Paket diterima kurir (first scan).',
                    at: ago(40),
                  ),
                ],
                isSample: true,
              ),
              TrackedShipment(
                awb: '004129841290',
                courier: 'SiCepat REG',
                orderNumber: 'XP2501182765',
                state: ShipmentState.inTransit,
                destinationCity: 'Kota Jakarta Selatan',
                buyerName: 'D******',
                checkpoints: <ShipmentCheckpoint>[
                  ShipmentCheckpoint(
                    location: 'Sorting Hub Jakarta Timur',
                    description:
                        'Paket keluar dari sorting hub menuju drop point '
                        'tujuan pengantaran akhir.',
                    at: ago(1),
                  ),
                  ShipmentCheckpoint(
                    location: 'Sorting Hub Jakarta Timur',
                    description: 'Paket diproses di sorting hub.',
                    at: ago(6),
                  ),
                  ShipmentCheckpoint(
                    location: 'Drop Point Kebayoran',
                    description: 'Paket diterima kurir (first scan).',
                    at: ago(10),
                  ),
                ],
                isSample: true,
              ),
              TrackedShipment(
                awb: 'JT991204812',
                courier: 'J&T Express EZ',
                orderNumber: 'XP2501174011',
                state: ShipmentState.delivered,
                destinationCity: 'Kota Surabaya',
                buyerName: 'A***** K*****',
                receivedBy: 'Satpam Komplek / Ybs',
                checkpoints: <ShipmentCheckpoint>[
                  ShipmentCheckpoint(
                    location: 'Terkirim ke Alamat',
                    description: 'Paket diterima oleh: Satpam Komplek / Ybs.',
                    at: ago(26),
                  ),
                  ShipmentCheckpoint(
                    location: 'Drop Point Surabaya',
                    description: 'Paket dibawa kurir untuk diantar.',
                    at: ago(30),
                  ),
                ],
                isSample: true,
              ),
              TrackedShipment(
                awb: 'JNE55667788990',
                courier: 'JNE YES',
                orderNumber: 'XP2501201177',
                state: ShipmentState.inTransit,
                destinationCity: 'Kota Semarang',
                buyerName: 'T**** S****',
                checkpoints: <ShipmentCheckpoint>[
                  ShipmentCheckpoint(
                    location: 'Hub Semarang',
                    description: 'Paket tiba di hub kota tujuan.',
                    at: ago(3, 20),
                  ),
                ],
                isSample: true,
              ),
            ]);
  }
}
