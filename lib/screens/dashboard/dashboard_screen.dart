// lib/screens/dashboard/dashboard_screen.dart


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';


import '../../config/constants.dart';
import '../../config/theme.dart';

import '../../providers/dashboard_provider.dart';


import '../../models/loan.dart';

import '../../models/payment.dart';

class DashboardScreen extends StatefulWidget {


  final Function(
      int targetTab, {
      Map<String,dynamic>? initialParams,
      }) onNavigate;

  const DashboardScreen({

    super.key,

    required this.onNavigate,

  });







  @override
  State<DashboardScreen> createState() =>

      _DashboardScreenState();



}








class _DashboardScreenState

    extends State<DashboardScreen>{





  static const double mobileBreakpoint = 600;

  static const double tabletBreakpoint = 1200;








  bool isMobile(double width){

    return width < mobileBreakpoint;

  }





  bool isTablet(double width){

    return width >= mobileBreakpoint &&
        width < tabletBreakpoint;

  }





  bool isDesktop(double width){

    return width >= tabletBreakpoint;

  }









  @override
  void initState(){


    super.initState();




    WidgetsBinding.instance

        .addPostFrameCallback((_) {



      if(!mounted) return;



      context

          .read<DashboardProvider>()

          .fetchSummary();



    });



  }









  @override
  Widget build(BuildContext context){



    final dashboard =

    context.watch<DashboardProvider>();



    final summary =

    dashboard.summary;



    final width =

    MediaQuery.of(context).size.width;




    final mobile =

    isMobile(width);



    final tablet =

    isTablet(width);



    final desktop =

    isDesktop(width);








    return Scaffold(




      backgroundColor:

      AppTheme.backgroundLight,







      body:

      RefreshIndicator(



        color:

        AppTheme.goldPrimary,



        onRefresh:

            ()=> dashboard.fetchSummary(),





        child:

        SingleChildScrollView(



          physics:

          const AlwaysScrollableScrollPhysics(),





          padding:

          EdgeInsets.all(

              mobile ? 10 :

              tablet ? 14 :

              20

          ),





          child:

          Column(



            crossAxisAlignment:

            CrossAxisAlignment.start,





            children:[





              _buildPremiumHeader(

                mobile,

              ),







              SizedBox(

                height:

                mobile ? 12 : 20,

              ),







              _buildSectionTitle(

                "BUSINESS OVERVIEW",

              ),






              const SizedBox(

                height:10,

              ),







              _buildKpiSection(

                summary,

                mobile,

                tablet,

                desktop,

              ),







              SizedBox(

                height:

                mobile ? 14 : 22,

              ),







              _buildSectionTitle(

                "QUICK OPERATIONS",

              ),







              const SizedBox(

                height:10,

              ),








              _buildQuickActions(

                mobile,

              ),







              SizedBox(

                height:

                mobile ? 14 : 22,

              ),







              _buildSectionTitle(

                "RECENT ACTIVITY",

              ),







              const SizedBox(

                height:10,

              ),







              _buildRecentActivity(

                context,

                summary,

                mobile,

                tablet,

                desktop,

              ),





            ],



          ),



        ),



      ),



    );



  }

  // ============================================================
// PREMIUM HEADER
// ============================================================


Widget _buildPremiumHeader(

    bool mobile,

){



  return Container(



    width:

    double.infinity,



    padding:

    EdgeInsets.all(

      mobile ? 14 : 20,

    ),





    decoration:

    BoxDecoration(



      gradient:

      AppTheme.darkNavyGradient,



      borderRadius:

      BorderRadius.circular(18),





      border:

      Border.all(



        color:

        AppTheme.goldPrimary

            .withValues(alpha: 0.5),



        width:

        1.2,



      ),



      boxShadow:[



        BoxShadow(



          color:

          Colors.black.withValues(alpha: 0.25),



          blurRadius:

          12,



          offset:

          const Offset(0,6),



        )



      ],



    ),





    child:

    Row(



      children:[





        Container(



          padding:

          const EdgeInsets.all(12),





          decoration:

          BoxDecoration(



            color:

            AppTheme.goldPrimary

                .withValues(alpha: 0.18),



            shape:

            BoxShape.circle,



          ),





          child:

          const Icon(



            Icons.account_balance,



            color:

            AppTheme.goldPrimary,



            size:

            30,



          ),



        ),






        const SizedBox(

          width:14,

        ),







        Expanded(



          child:

          Column(



            crossAxisAlignment:

            CrossAxisAlignment.start,



            children:[





              Text(



                "GOLD PAWN ERP",



                style:

                GoogleFonts.plusJakartaSans(



                  color:

                  AppTheme.goldPrimary,



                  fontSize:

                  mobile ? 18 : 24,



                  fontWeight:

                  FontWeight.w800,



                ),



              ),






              const SizedBox(

                height:4,

              ),





              Text(



                "Gold & Silver Pawn Loan Management System",



                style:

                TextStyle(



                  color:

                  Colors.white70,



                  fontSize:

                  mobile ? 11 : 13,



                ),



              ),






              const SizedBox(

                height:8,

              ),







              Container(



                padding:

                const EdgeInsets.symmetric(



                  horizontal:10,

                  vertical:5,



                ),





                decoration:

                BoxDecoration(



                  color:

                  Colors.green.shade700,



                  borderRadius:

                  BorderRadius.circular(20),



                ),





                child:

                const Text(



                  "● Database Connected",



                  style:

                  TextStyle(



                    color:

                    Colors.white,



                    fontSize:

                    10,



                    fontWeight:

                    FontWeight.bold,



                  ),



                ),



              ),





            ],



          ),



        ),





      ],



    ),



  );



}










// ============================================================
// SECTION TITLE
// ============================================================


Widget _buildSectionTitle(

    String title

){



  return Row(



    children:[





      Container(



        width:

        5,



        height:

        22,



        decoration:

        BoxDecoration(



          color:

          AppTheme.goldPrimary,



          borderRadius:

          BorderRadius.circular(10),



        ),



      ),





      const SizedBox(

        width:8,

      ),





      Text(



        title,



        style:

        GoogleFonts.plusJakartaSans(



          color:

          AppTheme.darkNavy,



          fontSize:

          14,



          fontWeight:

          FontWeight.w800,



        ),



      ),





    ],



  );



}

// ============================================================
// KPI SECTION
// ============================================================


Widget _buildKpiSection(

    dynamic summary,

    bool mobile,

    bool tablet,

    bool desktop,

){



  int columns;



  if(mobile){

    columns = 2;

  }

  else if(tablet){

    columns = 3;

  }

  else{

    columns = 5;

  }







  return GridView.count(



    shrinkWrap:true,



    physics:

    const NeverScrollableScrollPhysics(),



    crossAxisCount:

    columns,



    crossAxisSpacing:

    mobile ? 8 : 12,



    mainAxisSpacing:

    mobile ? 8 : 12,



    childAspectRatio:

    mobile ? 1.15 : 1.35,







    children:[





      _dashboardCard(

        title:"CUSTOMERS",

        value:

        summary.totalCustomers.toString(),

        subtitle:"Registered",

        icon:

        Icons.people,
        onTap: () => widget.onNavigate(1),

      ),







      _dashboardCard(

        title:"GOLD ITEMS",

        value:

        summary.totalGoldItems.toString(),

        subtitle:

        AppConstants.formatWeight(

          summary.totalGoldWeight,

        ),

        icon:

        Icons.diamond,

        gold:true,
        onTap: () => widget.onNavigate(4),

      ),







      _dashboardCard(

        title:"TOTAL LOAN",

        value:

        AppConstants.formatCurrency(

          summary.totalGivenLoan,

        ),

        subtitle:"Principal",

        icon:

        Icons.account_balance_wallet,

        gold:true,
        onTap: () => widget.onNavigate(2),

      ),







      _dashboardCard(

        title:"OUTSTANDING",

        value:

        AppConstants.formatCurrency(

          summary.totalOutstanding,

        ),

        subtitle:"Active Balance",

        icon:

        Icons.warning,

        gold:true,
        onTap: () => widget.onNavigate(2),

      ),







      _dashboardCard(

        title:"COLLECTION",

        value:

        AppConstants.formatCurrency(

          summary.totalCollection,

        ),

        subtitle:"Received",

        icon:

        Icons.payments,
        onTap: () => widget.onNavigate(3),

      ),







      _dashboardCard(

        title:"PARTIAL",

        value:

        AppConstants.formatCurrency(

          summary.totalPartial,

        ),

        subtitle:

        "${summary.totalPartialCount} Payments",

        icon:

        Icons.pie_chart,
        onTap: () => widget.onNavigate(3),

      ),







      _dashboardCard(

        title:"TODAY LOANS",

        value:

        summary.todayGivenLoanCount.toString(),

        subtitle:"Created Today",

        icon:

        Icons.today,
        onTap: () => widget.onNavigate(2),

      ),







      _dashboardCard(

        title:"CLOSED",

        value:

        summary.totalClosedLoans.toString(),

        subtitle:"Settled",

        icon:

        Icons.check_circle,
        onTap: () => widget.onNavigate(2),

      ),







      _dashboardCard(

        title:"RELEASE",

        value:

        summary.totalReleases.toString(),

        subtitle:"Gold Released",

        icon:

        Icons.lock_open,
        onTap: () => widget.onNavigate(5),

      ),




    ],



  );



}












// ============================================================
// KPI CARD
// ============================================================


Widget _dashboardCard({
  required String title,
  required String value,
  required String subtitle,
  required IconData icon,
  bool gold = false,
  VoidCallback? onTap,
}) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gold
                ? [
                    const Color(0xffFFF4C2),
                    Colors.white,
                  ]
                : [
                    Colors.white,
                    const Color(0xffF5F5F5),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gold
                ? AppTheme.goldPrimary
                : AppTheme.silverBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: gold
                      ? AppTheme.goldDark
                      : AppTheme.darkNavy,
                ),
                const Spacer(),
                if (onTap != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: gold
                          ? AppTheme.goldPrimary.withValues(alpha: 0.18)
                          : AppTheme.darkNavy.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VIEW',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ),
                if (gold) ...[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.workspace_premium,
                    size: 16,
                    color: Color(0xffD4AF37),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkNavy,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// QUICK ACTIONS
// ============================================================


Widget _buildQuickActions(

    bool mobile,

){



  final actions = [



    _QuickAction(

      "New Customer",

      Icons.person_add,

      true,

      () => widget.onNavigate(

        1,

        initialParams:{

          "action":"new_customer"

        },

      ),

    ),




    _QuickAction(

      "Existing Customer",

      Icons.person_search,

      false,

      () => widget.onNavigate(1),

    ),






    _QuickAction(

      "New Pawn Loan",

      Icons.add_circle,

      true,

      () => widget.onNavigate(

        2,

        initialParams:{

          "action":"new_loan"

        },

      ),

    ),







    _QuickAction(

      "Additional Loan",

      Icons.add_card,

      false,

      () => widget.onNavigate(

        2,

        initialParams:{

          "action":"additional_loan"

        },

      ),

    ),







    _QuickAction(

      "Payment",

      Icons.payments,

      true,

      () => widget.onNavigate(

        3,

        initialParams:{

          "action":"new_payment"

        },

      ),

    ),







    _QuickAction(

      "Partial Payment",

      Icons.pie_chart,

      false,

      () => widget.onNavigate(

        3,

        initialParams:{

          "action":"new_payment"

        },

      ),

    ),







    _QuickAction(

      "Close Loan",

      Icons.lock,

      false,

      () => widget.onNavigate(

        2,

        initialParams:{

          "action":"close_loan"

        },

      ),

    ),







    _QuickAction(

      "Receipts",

      Icons.receipt_long,

      false,

      () => widget.onNavigate(6),

    ),





  ];









  return Container(



    padding:

    const EdgeInsets.all(14),





    decoration:

    BoxDecoration(



      color:

      Colors.white,



      borderRadius:

      BorderRadius.circular(18),





      border:

      Border.all(

        color:

        AppTheme.silverBorder,

      ),



    ),







    child:

    LayoutBuilder(



      builder:

          (context,constraints){





        int columns;





        if(constraints.maxWidth < 450){

          columns=2;

        }

        else if(constraints.maxWidth < 800){

          columns=3;

        }

        else{

          columns=5;

        }







        return Wrap(



          spacing:

          10,



          runSpacing:

          10,



          children:

          actions.map((action){





            final width =

            (constraints.maxWidth -

                ((columns-1)*10))

                /

                columns;







            return SizedBox(



              width:

              width,



              child:

              _quickButton(action),



            );





          }).toList(),



        );





      },



    ),



  );



}














Widget _quickButton(

    _QuickAction action

){



  return InkWell(



    onTap:

    action.onTap,



    borderRadius:

    BorderRadius.circular(14),





    child:

    Container(



      height:

      70,





      decoration:

      BoxDecoration(



        gradient:

        action.primary

            ?

       const LinearGradient(

          colors:[

            AppTheme.goldPrimary,

         Color(0xffF7E7A9),

          ],

        )

            :

        const LinearGradient(

          colors:[

            Colors.white,

            Color(0xffF1F1F1),

          ],

        ),





        borderRadius:

        BorderRadius.circular(14),





        border:

        Border.all(

          color:

          AppTheme.silverBorder,

        ),



      ),







      child:

      Column(



        mainAxisAlignment:

        MainAxisAlignment.center,



        children:[





          Icon(



            action.icon,



            size:

            25,



            color:

            Colors.black,



          ),





          const SizedBox(

            height:6,

          ),





          Text(



            action.label,



            textAlign:

            TextAlign.center,



            maxLines:

            2,



            overflow:

            TextOverflow.ellipsis,



            style:

            const TextStyle(



              fontSize:

              10,



              fontWeight:

              FontWeight.bold,



            ),



          ),





        ],



      ),



    ),



  );



}

// ============================================================
// RECENT ACTIVITY
// ============================================================


Widget _buildRecentActivity(

    BuildContext context,

    dynamic summary,

    bool mobile,

    bool tablet,

    bool desktop,

){



  if(desktop){


    return Row(


      children:[



        Expanded(

          child:

          _activityCard(

            "RECENT LOANS",

            Icons.account_balance,

            _loanActivity(summary.recentLoans),

          ),

        ),




        const SizedBox(width:15),






        Expanded(

          child:

          _activityCard(

            "RECENT PAYMENTS",

            Icons.payments,

            _paymentActivity(summary.recentPayments),

          ),

        ),






      ],



    );



  }






  return Column(



    children:[



      _activityCard(

        "RECENT LOANS",

        Icons.account_balance,

        _loanActivity(summary.recentLoans),

      ),



      const SizedBox(height:15),




      _activityCard(

        "RECENT PAYMENTS",

        Icons.payments,

        _paymentActivity(summary.recentPayments),

      ),



    ],



  );



}











// ============================================================
// ACTIVITY CARD
// ============================================================


Widget _activityCard(

    String title,

    IconData icon,

    Widget child,

){



  return Container(



    padding:

    const EdgeInsets.all(15),





    decoration:

    BoxDecoration(



      color:

      Colors.white,



      borderRadius:

      BorderRadius.circular(18),





      border:

      Border.all(

        color:

        AppTheme.silverBorder,

      ),



    ),





    child:

    Column(



      crossAxisAlignment:

      CrossAxisAlignment.start,



      children:[





        Row(



          children:[



            Icon(

              icon,

              color:

              AppTheme.goldDark,

            ),




            const SizedBox(width:8),





            Text(



              title,



              style:

              const TextStyle(



                fontWeight:

                FontWeight.bold,



                fontSize:

                14,



              ),



            ),



          ],



        ),





        const Divider(),





        child,





      ],



    ),



  );



}












// ============================================================
// LOAN ACTIVITY
// ============================================================


Widget _loanActivity(

    List<Loan> loans

){



  if(loans.isEmpty){



    return const Text(

      "No recent loans",

    );



  }






  return Column(



    children:

    loans.map((loan){



      return _activityRow(



        loan.loanNo,



        AppConstants.formatCurrency(

          loan.principalAmount,

        ),



        loan.status,



      );



    }).toList(),



  );



}











// ============================================================
// PAYMENT ACTIVITY
// ============================================================


Widget _paymentActivity(

    List<Payment> payments

){



  if(payments.isEmpty){



    return const Text(

      "No recent payments",

    );



  }






  return Column(



    children:

    payments.map((payment){



      return _activityRow(



        payment.receiptNo,



        AppConstants.formatCurrency(

          payment.amount,

        ),



        "Paid",



      );



    }).toList(),



  );



}











// ============================================================
// ACTIVITY ROW
// ============================================================


Widget _activityRow(



    String title,

    String amount,

    String status,



){



  return Container(



    margin:

    const EdgeInsets.only(

      bottom:10,

    ),





    padding:

    const EdgeInsets.all(10),






    decoration:

    BoxDecoration(



      color:

      const Color(0xffF8F8F8),



      borderRadius:

      BorderRadius.circular(12),



    ),





    child:

    Row(



      children:[



        Expanded(



          child:

          Column(



            crossAxisAlignment:

            CrossAxisAlignment.start,



            children:[



              Text(



                title,



                style:

                const TextStyle(



                  fontWeight:

                  FontWeight.bold,



                ),



              ),





              Text(



                status,



                style:

                const TextStyle(



                  fontSize:

                  11,



                  color:

                  Colors.black54,



                ),



              ),



            ],



          ),



        ),





        Text(



          amount,



          style:

          const TextStyle(



            fontWeight:

            FontWeight.bold,



            color:

            Color(0xffB8860B),



          ),



        ),





      ],



    ),



  );



}
}


// ============================================================
// QUICK ACTION MODEL
// ============================================================


class _QuickAction {


  final String label;


  final IconData icon;


  final bool primary;


  final VoidCallback onTap;





  const _QuickAction(

      this.label,

      this.icon,

      this.primary,

      this.onTap,

      );



}
    