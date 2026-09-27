import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CentresListScreen extends StatelessWidget {
  const CentresListScreen({super.key});

  final List<Map<String, dynamic>> centres = const [
    {
      'name': 'Kancheepuram Procurement Centre',
      'code': 'CTR001',
      'district': 'Kancheepuram',
      'capacity': 150,
      'waiting': 1,
      'processing': 1,
      'status': 'Open',
    },
    {
      'name': 'Sriperumbudur Procurement Centre',
      'code': 'CTR002',
      'district': 'Kancheepuram',
      'capacity': 120,
      'waiting': 1,
      'processing': 0,
      'status': 'Open',
    },
    {
      'name': 'Walajabad Procurement Centre',
      'code': 'CTR003',
      'district': 'Kancheepuram',
      'capacity': 100,
      'waiting': 1,
      'processing': 0,
      'status': 'Open',
    },
    {
      'name': 'Uthiramerur Procurement Centre',
      'code': 'CTR004',
      'district': 'Kancheepuram',
      'capacity': 130,
      'waiting': 0,
      'processing': 0,
      'status': 'Open',
    },
  ];

  Future<void> _openMaps(
      BuildContext context,
      String name,
      String district,
      ) async {
    final query = Uri.encodeComponent(
      '$name, $district, Tamil Nadu',
    );

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Google Maps'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF12372A),
          ),
        ),

        title: const Text(
          'Procurement Centres',
          style: TextStyle(
            color: Color(0xFF12372A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------------------------------------------------------
          // HEADER
          // ---------------------------------------------------------------

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF12372A),
                  Color(0xFF2E7D32),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_city_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(height: 12),
                Text(
                  'Find a Procurement Centre',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Check centre capacity, waiting farmers and current processing status.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Available Centres',
            style: TextStyle(
              color: Color(0xFF12372A),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          // ---------------------------------------------------------------
          // CENTRES
          // ---------------------------------------------------------------

          ...centres.map(
                (centre) {
              final name =
              centre['name'] as String;

              final code =
              centre['code'] as String;

              final district =
              centre['district'] as String;

              final capacity =
              centre['capacity'] as int;

              final waiting =
              centre['waiting'] as int;

              final processing =
              centre['processing'] as int;

              final status =
              centre['status'] as String;

              final utilization =
              ((waiting + processing) /
                  capacity *
                  100)
                  .clamp(0, 100);

              return Container(
                margin:
                const EdgeInsets.only(bottom: 14),

                padding:
                const EdgeInsets.all(17),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(20),
                  border: Border.all(
                    color:
                    const Color(0xFFE0E7E2),
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // -----------------------------------------------------
                    // NAME
                    // -----------------------------------------------------

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFFE8F5E9,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .location_on_rounded,
                            color:
                            Color(0xFF16834B),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                name,
                                style:
                                const TextStyle(
                                  color:
                                  Color(
                                    0xFF17221D,
                                  ),
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                '$code • $district',
                                style:
                                const TextStyle(
                                  color:
                                  Color(
                                    0xFF718078,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFFE8F5E9,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              20,
                            ),
                          ),
                          child: const Text(
                            'OPEN',
                            style:
                            TextStyle(
                              color:
                              Color(
                                0xFF16834B,
                              ),
                              fontSize: 9,
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------
                    // METRICS
                    // -----------------------------------------------------

                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                            Icons
                                .people_outline,
                            '$waiting',
                            'Waiting',
                          ),
                        ),
                        Expanded(
                          child: _metric(
                            Icons
                                .sync_rounded,
                            '$processing',
                            'Processing',
                          ),
                        ),
                        Expanded(
                          child: _metric(
                            Icons
                                .inventory_2_outlined,
                            '$capacity',
                            'Capacity',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------
                    // UTILIZATION
                    // -----------------------------------------------------

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Centre utilization',
                            style: TextStyle(
                              color:
                              Color(
                                0xFF59665F,
                              ),
                              fontSize: 11,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ),
                        Text(
                          '${utilization.toStringAsFixed(0)}%',
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF16834B,
                            ),
                            fontSize: 11,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                      child:
                      LinearProgressIndicator(
                        minHeight: 7,
                        value:
                        utilization / 100,
                        backgroundColor:
                        const Color(
                          0xFFE8EEE9,
                        ),
                        color:
                        const Color(
                          0xFF16834B,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // -----------------------------------------------------
                    // CONGESTION
                    // -----------------------------------------------------

                    Row(
                      children: [
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFFE8F5E9,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              20,
                            ),
                          ),
                          child: Text(
                            utilization >= 80
                                ? 'High congestion'
                                : utilization >=
                                50
                                ? 'Medium congestion'
                                : 'Low congestion',
                            style:
                            const TextStyle(
                              color:
                              Color(
                                0xFF16834B,
                              ),
                              fontSize: 10,
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),
                        ),

                        const Spacer(),

                        Text(
                          status,
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF16834B,
                            ),
                            fontSize: 11,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // -----------------------------------------------------
                    // DIRECTIONS
                    // -----------------------------------------------------

                    SizedBox(
                      width: double.infinity,
                      child:
                      OutlinedButton.icon(
                        onPressed: () {
                          _openMaps(
                            context,
                            name,
                            district,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .directions_outlined,
                          size: 19,
                        ),
                        label: const Text(
                          'Get Directions',
                        ),
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          const Color(
                            0xFF16834B,
                          ),
                          side:
                          const BorderSide(
                            color:
                            Color(
                              0xFF9BCDAE,
                            ),
                          ),
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 12,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metric(
      IconData icon,
      String value,
      String label,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF16834B),
          size: 20,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF718078),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}