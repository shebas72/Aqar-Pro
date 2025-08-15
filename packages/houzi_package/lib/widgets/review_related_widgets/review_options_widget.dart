import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:houzi_package/api_management/api_handlers/api_manager.dart';
import 'package:houzi_package/common/constants.dart';
import 'package:houzi_package/files/app_preferences/app_preferences.dart';
import 'package:houzi_package/files/generic_methods/utility_methods.dart';
import 'package:houzi_package/files/hive_storage_files/hive_storage_manager.dart';
import 'package:houzi_package/models/api/api_response.dart';
import 'package:houzi_package/pages/filter_page.dart';
import 'package:houzi_package/pages/search_result.dart';
import 'package:houzi_package/widgets/custom_widgets/alert_dialog_widget.dart';
import 'package:houzi_package/widgets/custom_widgets/text_button_widget.dart';
import 'package:houzi_package/widgets/generic_text_widget.dart';
import 'package:houzi_package/widgets/toast_widget.dart';

import '../../pages/home_screen_drawer_menu_pages/user_related/user_signin.dart';

typedef ReviewOptionsWidgetListener = Function({
    int? contentItemID
});

class ReviewOptionsWidget extends StatelessWidget {
  final int contentItemID;
  final String reportNonce;

  final ReviewOptionsWidgetListener listener;

  ReviewOptionsWidget({
    Key? key,
    required this.contentItemID,
    required this.reportNonce,

    required this.listener,
  }) : super(key: key);

  String? idToReport;
  final ApiManager _apiManager = ApiManager();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PopupMenuButton(
          surfaceTintColor: Colors.transparent,
          color: AppThemePreferences().appTheme.popUpMenuBgColor,
          offset: Offset(0, 50),
          elevation: AppThemePreferences.popupMenuElevation,
          icon: Icon(
            Icons.more_horiz_outlined,
            color: AppThemePreferences().appTheme.iconsColor,
          ),
          onSelected: (value) {

            if (value == OPTION_REPORT) {
              bool isLoggedIn = HiveStorageManager.isUserLoggedIn();
              if (isLoggedIn) {
                onReportTap(context);
              } else {
                Route route = MaterialPageRoute(
                  builder: (context) => UserSignIn(
                        (String closeOption) {
                      if (closeOption == CLOSE) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
                Navigator.push(context, route);
              }

            }
          },
          itemBuilder: (context) {
            return [
              GenericPopupMenuItem(
                value: OPTION_REPORT,
                text: UtilityMethods.getLocalizedString("report"),
                iconData: AppThemePreferences.reportIcon,
              ),

            ];
          },
        )
        // SizedBox(height: 50),
      ],
    );
  }

  PopupMenuItem GenericPopupMenuItem({
    required dynamic value,
    required String text,
    required IconData iconData,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            iconData,
            size: 18,
            color: AppThemePreferences().appTheme.iconsColor,
          ),
          SizedBox(width: 10),
          GenericTextWidget(
            text,
            style: AppThemePreferences().appTheme.subBody01TextStyle,
          ),
        ],
      ),
    );
  }

  onReportTap(BuildContext context) {

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialogWidget(
        title: GenericTextWidget(UtilityMethods.getLocalizedString("report")),
        content: GenericTextWidget(
            UtilityMethods.getLocalizedString("report_confirmation")),
        actions: <Widget>[
          TextButtonWidget(
            onPressed: () => Navigator.pop(context),
            child:
            GenericTextWidget(UtilityMethods.getLocalizedString("cancel")),
          ),
          TextButtonWidget(
            onPressed: () async {

              Map<String, dynamic> params = {
                ContentIdKey : contentItemID,
                ContentTypeKey : "review",
              };

              ApiResponse<String> response = await _apiManager.reportContent(params, reportNonce);

              if (response.success && response.internet) {
                listener(contentItemID: contentItemID);
                _showToast(context, response.message);
                Navigator.of(context).pop();
              } else {
                String _message = "error_occurred";
                if (response.message.isNotEmpty) {
                  _message = response.message;
                }
                _showToast(context, _message);
              }
            },
            child: GenericTextWidget(UtilityMethods.getLocalizedString("yes")),
          ),
        ],
      ),
    );
  }

  _showToast(BuildContext context, String msg) {
    ShowToastWidget(
      buildContext: context,
      text: msg,
    );
  }
}
