import 'package:flutter/material.dart';
import 'signup_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  String? _selectedConsent;
  final _mainScrollController = ScrollController();
  final _consentScrollController = ScrollController();

  @override
  void dispose() {
    _mainScrollController.dispose();
    _consentScrollController.dispose();
    super.dispose();
  }

  void _handleAgree() {
    if (_selectedConsent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an option'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedConsent == 'agree') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignupScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to continue registration'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0a1e5e), Color(0xFF1a3a8a), Color(0xFF2563eb)],
          ),
        ),
        child: SafeArea(
          child: SelectionArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _mainScrollController,
                  thumbVisibility: true,
                  thickness: 8,
                  radius: const Radius.circular(4),
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563eb), Color(0xFF1e40af)],
                              ),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 60,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo
                                Image.asset(
                                  'assets/images/unai_logo.png',
                                  width: 200,
                                  height: 120,
                                ),
                                const SizedBox(height: 16),

                                // Title
                                const Text(
                                  'ประกาศคุ้มครองข้อมูลส่วนบุคคล',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'ระบบ UNAi Chat bot',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                // Consent Box
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      // Scrollable Consent Content
                                      Container(
                                        height: 250,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        child: SelectionArea(
                                          child: Scrollbar(
                                            controller:
                                                _consentScrollController,
                                            thumbVisibility: true,
                                            thickness: 6,
                                            child: SingleChildScrollView(
                                              controller:
                                                  _consentScrollController,
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'วัตถุประสงค์',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'ระบบ UNAi CHAT BOT จัดทำขึ้นเพื่อให้บริการตอบคำถามและช่วยแก้ไขปัญหาเบื้องต้นแก่ผู้ใช้งาน โดยมีความจำเป็นต้องเก็บรวบรวม ใช้ และบันทึกข้อมูลส่วนบุคคลของผู้ใช้งาน เพื่อให้',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      '• ผู้ใช้งานสามารถตรวจสอบและเรียกดูประวัติการสนทนาย้อนหลังได้',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 8,
                                                        ),
                                                    child: Text(
                                                      '• ผู้พัฒนาระบบสามารถนำข้อมูลไปใช้ในการวิเคราะห์ ปรับปรุง และพัฒนาประสิทธิภาพการให้บริการของระบบ',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  const Text(
                                                    'ทั้งนี้ ระบบจะเก็บรวบรวม ใช้ และบันทึกข้อมูลส่วนบุคคลเท่าที่จำเป็นตามวัตถุประสงค์ดังกล่าวเท่านั้น',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'ประเภทข้อมูลส่วนบุคคลที่มีการเก็บรวบรวม',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      '• ข้อความที่ใช้สนทนากับระบบแชทบอท',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      '• วันและเวลาที่เข้าใช้งานระบบ',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 8,
                                                        ),
                                                    child: Text(
                                                      '• ข้อมูลทางเทคนิคที่เกี่ยวข้องกับการใช้งานระบบ เช่น Log File',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'ระยะเวลาการเก็บรักษาข้อมูล',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'ระบบจะเก็บรวบรวม ใช้ และบันทึกข้อมูลส่วนบุคคลตามวัตถุประสงค์ เป็นระยะเวลาเท่าที่จำเป็น หรือ ตลอดระยะเวลาที่ผู้ใช้งานยังมีบัญชีผู้ใช้งานในระบบ',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'ทั้งนี้ ผู้ใช้งานสามารถใช้สิทธิในการลบข้อมูลส่วนบุคคล หรือลบบัญชีผู้ใช้งานเพื่อเพิกถอนความยินยอมได้ตลอดเวลา',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'สิทธิของเจ้าของข้อมูลส่วนบุคคล',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'เจ้าของข้อมูลส่วนบุคคลมีสิทธิตามกฎหมายคุ้มครองข้อมูลส่วนบุคคล ดังต่อไปนี้',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      '• สิทธิในการเข้าถึงและขอรับสำเนาข้อมูลส่วนบุคคลของตน',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      '• สิทธิในการขอแก้ไขข้อมูลส่วนบุคคลให้ถูกต้องและเป็นปัจจุบัน',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      '• สิทธิในการลบหรือทำลายข้อมูลส่วนบุคคล',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          bottom: 8,
                                                        ),
                                                    child: Text(
                                                      '• สิทธิในการเพิกถอนความยินยอมในการประมวลผลข้อมูลส่วนบุคคล',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  const Text(
                                                    'การเพิกถอนความยินยอมจะไม่กระทบต่อการประมวลผลข้อมูลส่วนบุคคลที่ได้ดำเนินการไปแล้วโดยชอบด้วยกฎหมายก่อนการเพิกถอน',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'กรณีไม่ให้ความยินยอม',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'หากท่านไม่ประสงค์ให้ความยินยอม ระบบจะไม่บันทึกประวัติการสนทนาของท่าน',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'ทั้งนี้ ท่านยังสามารถเลือกใช้งานระบบในโหมด Guest ซึ่งจะไม่มีการจัดเก็บข้อมูลการสนทนาใด ๆ',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'การรักษาความมั่นคงปลอดภัยของข้อมูล',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'ระบบ UNAi CHAT BOT จัดให้มีมาตรการรักษาความมั่นคงปลอดภัยของข้อมูลส่วนบุคคลที่เหมาะสม เพื่อป้องกันการเข้าถึง การใช้ การแก้ไข หรือการเปิดเผยข้อมูลส่วนบุคคลโดยปราศจากอำนาจหรือโดยมิชอบ และจะไม่เปิดเผยข้อมูลส่วนบุคคลแก่บุคคลภายนอก เว้นแต่เป็นไปตามที่กฎหมายกำหนด',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'การให้ความยินยอม',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'ข้าพเจ้าได้อ่านและเข้าใจรายละเอียดเกี่ยวกับการเก็บรวบรวม ใช้ และบันทึกข้อมูลส่วนบุคคลตามที่ระบุไว้ข้างต้นแล้ว',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Radio Options
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // ยินยอม
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _selectedConsent = 'agree';
                                                });
                                              },
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            _selectedConsent ==
                                                                'agree'
                                                            ? const Color(
                                                                0xFF1e40af,
                                                              )
                                                            : Colors.grey,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child:
                                                          _selectedConsent ==
                                                              'agree'
                                                          ? Container(
                                                              width: 12,
                                                              height: 12,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Color(
                                                                      0xFF1e40af,
                                                                    ),
                                                                  ),
                                                            )
                                                          : const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'ยินยอม',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // ไม่ยินยอม
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _selectedConsent = 'disagree';
                                                });
                                              },
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            _selectedConsent ==
                                                                'disagree'
                                                            ? const Color(
                                                                0xFF1e40af,
                                                              )
                                                            : Colors.grey,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child:
                                                          _selectedConsent ==
                                                              'disagree'
                                                          ? Container(
                                                              width: 12,
                                                              height: 12,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Color(
                                                                      0xFF1e40af,
                                                                    ),
                                                                  ),
                                                            )
                                                          : const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'ไม่ยินยอม',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Buttons
                                Row(
                                  children: [
                                    // Cancel Button
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _handleCancel,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1e3a8a,
                                            ),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                          ),
                                          child: const Text(
                                            'CANCEL',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Agree Button
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _handleAgree,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1e3a8a,
                                            ),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                          ),
                                          child: const Text(
                                            'AGREE',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
