codeunit 139054 "Office Addin Redeploy"
{
    Subtype = Test;
    TestPermissions = NonRestrictive;

    trigger OnRun()
    begin
        // [FEATURE] [Office Add-in]
    end;

    var
        Assert: Codeunit Assert;
        LibraryOfficeHostProvider: Codeunit "Library - Office Host Provider";
        OfficeHostType: DotNet OfficeHostType;
        FieldNotDisplayedErr: Label '%1  field is not displayed';
        FieldIsDisplayedErr: Label '%1  field is displayed';
        ApplicationIDTxt: Label 'cfca30bd-9846-4819-a6fc-56c89c5aae96';

    [Test]
    [HandlerFunctions('RedeployUserNonBreakingPageHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployUserNonBreaking()
    var
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        UserVersion: Text;
    begin
        // [GIVEN] User deployed addin and has non breaking update available
        UpdateOfficeAddinTable(0D, false, UserVersion);

        // [THEN] User is prompted to update now or update later
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [HandlerFunctions('RedeployUserBreakingPageHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployUserBreaking()
    var
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        UserVersion: Text;
    begin
        // [GIVEN] User deployed addin and has a breaking update available
        UpdateOfficeAddinTable(0D, true, UserVersion);

        // [THEN] User is prompted to update now
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [HandlerFunctions('RedeployAdminNonBreakingPageHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployAdminNonBreaking()
    var
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        UserVersion: Text;
    begin
        // [GIVEN] Admin deployed addin and has a non breaking update available
        UpdateOfficeAddinTable(Today, false, UserVersion);

        // [THEN] User is prompted to notify admin and continue
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [HandlerFunctions('RedeployAdminBreakingPageHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployAdminBreaking()
    var
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        UserVersion: Text;
    begin
        // [GIVEN] Admin deployed addin and has a breaking update available
        UpdateOfficeAddinTable(Today, true, UserVersion);

        // [THEN] User is prompted to notify admin and cannot continue
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [HandlerFunctions('RedeployUpdateNowPageHandler,RedeployPromptHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployUpdateNowPrompts()
    var
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        UserVersion: Text;
    begin
        // [GIVEN] User deployed addin and has non breaking update available
        UpdateOfficeAddinTable(0D, false, UserVersion);

        // [THEN] User updates now and user is prompted for O365 credentials
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [HandlerFunctions('RedeployUpdateLaterPageHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployUpdateLater()
    var
        UserVersion: Text;
    begin
        // [GIVEN] User deployed addin and has non breaking update available
        UpdateOfficeAddinTable(0D, false, UserVersion);

        // [THEN] User updates later and addin is loaded
        InitializeOfficeHostProvider(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure ValidateRedeployIgnored()
    var
        InstructionMgt: Codeunit "Instruction Mgt.";
        UserVersion: Text;
    begin
        // [GIVEN] User deployed addin and has non breaking update available
        UpdateOfficeAddinTable(0D, false, UserVersion);

        // [WHEN] User has chosen to ignore updating notification
        // Force update notification disabled
        InstructionMgt.DisableMessageForCurrentUser(InstructionMgt.OfficeUpdateNotificationCode);

        // [THEN] Update notifcation is not displayed and addin is loaded
        InitializeOfficeHostProvider(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [HandlerFunctions('RedeployUserIgnoredPageHandler,RedeployIgnoredMsgHandler')]
    [Scope('OnPrem')]
    procedure ValidateRedeployUserIgnored()
    var
        InstructionMgt: Codeunit "Instruction Mgt.";
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        UserVersion: Text;
    begin
        // [GIVEN] User deployed addin and has non breaking update available
        // Force update notification enabled
        InstructionMgt.EnableMessageForCurrentUser(InstructionMgt.OfficeUpdateNotificationCode);
        UpdateOfficeAddinTable(0D, false, UserVersion);

        // [WHEN] User choses to ignore notification and updates later
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, UserVersion);

        // [THEN] User is not prompted to update and addin is loaded
        InitializeOfficeHostProvider(OfficeHostType.OutlookItemRead, UserVersion);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure ValidateAddinHostType()
    var
        OfficeAddin: Record "Office Add-in";
        AddinManifestManagement: Codeunit "Add-in Manifest Management";
    begin
        AddinManifestManagement.CreateDefaultAddins(OfficeAddin);

        // [WHEN] Hyperlink host type is provided
        AddinManifestManagement.GetAddinByHostType(OfficeAddin, OfficeHostType.OutlookHyperlink);

        // [THEN] Expected addin is returned
        Assert.AreNotEqual(ApplicationIDTxt, OfficeAddin."Application ID", 'Application IDs match');
    end;

    [Test]
    [HandlerFunctions('RedeployUserBreakingPageHandler')]
    [Scope('OnPrem')]
    procedure ValidateCheckVersionUpgradesAddinTable()
    var
        OfficeAddin: Record "Office Add-in";
        AddinDeploymentHelper: Codeunit "Add-in Deployment Helper";
        AddinManifestManagement: Codeunit "Add-in Manifest Management";
        LatestVersion: Text;
    begin
        // [SCENARIO 255867] Add-in table is updated when the version of the manifest has changed.

        // [GIVEN] Default add-ins have been created
        AddinManifestManagement.CreateDefaultAddins(OfficeAddin);
        AddinManifestManagement.GetAddinVersion(LatestVersion, CODEUNIT::"Intelligent Info Manifest");

        // [GIVEN] The add-in manifest version in the related codeunit has changed
        // Note: We simulate this by changing the version in the record (as we
        // cannot change a text constant, whence the manifest version originates.
        OfficeAddin.Get(ApplicationIDTxt);
        OfficeAddin.Version := '0.0.0.0';
        Clear(OfficeAddin.Manifest);
        OfficeAddin.Modify(true);

        // [WHEN] The user launches the add-in
        AddinDeploymentHelper.CheckVersion(OfficeHostType.OutlookItemRead, '0.0.0.0');

        // [THEN] The add-in record is updated to the latest version
        OfficeAddin.Find;
        OfficeAddin.TestField(Version, LatestVersion);
    end;

    local procedure InitializeOfficeHostProvider(HostType: Text; UserVersion: Text)
    var
        OfficeAddinContext: Record "Office Add-in Context";
        OfficeManagement: Codeunit "Office Management";
        OutlookMailEngine: TestPage "Outlook Mail Engine";
        OfficeNewContactDlg: TestPage "Office New Contact Dlg";
        OfficeHost: DotNet OfficeHost;
        TestEmail: Text[50];
    begin
        Clear(LibraryOfficeHostProvider);
        BindSubscription(LibraryOfficeHostProvider);

        OfficeAddinContext.DeleteAll();
        SetOfficeHostUnAvailable;

        SetOfficeHostProvider(CODEUNIT::"Library - Office Host Provider");

        OfficeManagement.InitializeHost(OfficeHost, HostType);

        TestEmail := StrSubstNo('%1@%2', CreateGuid, 'example.com');
        OfficeAddinContext.SetFilter(Email, TestEmail);
        OfficeAddinContext.SetFilter(Version, UserVersion);

        OutlookMailEngine.Trap;
        OfficeNewContactDlg.Trap;
        PAGE.Run(PAGE::"Outlook Mail Engine", OfficeAddinContext);

        OfficeNewContactDlg.Close;
    end;

    local procedure SetOfficeHostUnAvailable()
    var
        NameValueBuffer: Record "Name/Value Buffer";
    begin
        // Test Providers checks whether we have registered Host in NameValueBuffer or not
        if NameValueBuffer.Get(SessionId) then begin
            NameValueBuffer.Delete();
            Commit();
        end;
    end;

    local procedure SetOfficeHostProvider(ProviderId: Integer)
    var
        OfficeAddinSetup: Record "Office Add-in Setup";
    begin
        OfficeAddinSetup.Get();
        OfficeAddinSetup."Office Host Codeunit ID" := ProviderId;
        OfficeAddinSetup.Modify();
    end;

    local procedure UpdateOfficeAddinTable(AdminDeployedDate: Date; Breaking: Boolean; var UserVersion: Text)
    var
        OfficeAddin: Record "Office Add-in";
        AddinManifestManagement: Codeunit "Add-in Manifest Management";
        LatestVersion: Text[20];
    begin
        if not OfficeAddin.Get(ApplicationIDTxt) then
            OfficeAddin."Application ID" := ApplicationIDTxt;

        OfficeAddin."Deployment Date" := AdminDeployedDate;

        AddinManifestManagement.GetAddinVersion(LatestVersion, CODEUNIT::"Intelligent Info Manifest");
        OfficeAddin.Version := LatestVersion;

        if Breaking then
            UserVersion := '0.0.0.0'
        else
            UserVersion := LatestVersion + '01';

        if not OfficeAddin.Modify then
            OfficeAddin.Insert();

        Commit();
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployUserNonBreakingPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        Assert.IsTrue(OfficeUpdateAvailableDlg.UserNonBreaking.Visible, StrSubstNo(FieldNotDisplayedErr, 'UserNonBreaking'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.UpgradeLater.Visible, StrSubstNo(FieldNotDisplayedErr, 'UpgradeLater'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.UpgradeNow.Visible, StrSubstNo(FieldNotDisplayedErr, 'UpgradeNow'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.DontShowAgain.Visible, StrSubstNo(FieldNotDisplayedErr, 'DontShowAgain'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UserBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'UserBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.AdminNonBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'AdminNonBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.AdminBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'AdminBreaking'));
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployUserBreakingPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        Assert.IsTrue(OfficeUpdateAvailableDlg.UserBreaking.Visible, StrSubstNo(FieldNotDisplayedErr, 'UserBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UpgradeLater.Visible, StrSubstNo(FieldIsDisplayedErr, 'UpgradeLater'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.UpgradeNow.Visible, StrSubstNo(FieldNotDisplayedErr, 'UpgradeNow'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.DontShowAgain.Visible, StrSubstNo(FieldIsDisplayedErr, 'DontShowAgain'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UserNonBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'UserNonBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.AdminNonBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'AdminNonBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.AdminBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'AdminBreaking'));
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployAdminNonBreakingPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        Assert.IsFalse(OfficeUpdateAvailableDlg.UserBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'UserBreaking'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.UpgradeLater.Visible, StrSubstNo(FieldNotDisplayedErr, 'UpgradeLater'));
        Assert.AreEqual(OfficeUpdateAvailableDlg.UpgradeLater.Value, 'Continue', 'Upgrade later was not changed');
        Assert.IsFalse(OfficeUpdateAvailableDlg.UpgradeNow.Visible, StrSubstNo(FieldIsDisplayedErr, 'UpgradeNow'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.DontShowAgain.Visible, StrSubstNo(FieldNotDisplayedErr, 'DontShowAgain'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UserNonBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'UserNonBreaking'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.AdminNonBreaking.Visible, StrSubstNo(FieldNotDisplayedErr, 'AdminNonBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.AdminBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'AdminBreaking'));
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployAdminBreakingPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        Assert.IsFalse(OfficeUpdateAvailableDlg.UserBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'UserBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UpgradeLater.Visible, StrSubstNo(FieldIsDisplayedErr, 'UpgradeLater'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UpgradeNow.Visible, StrSubstNo(FieldIsDisplayedErr, 'UpgradeNow'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.DontShowAgain.Visible, StrSubstNo(FieldIsDisplayedErr, 'DontShowAgain'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.UserNonBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'UserNonBreaking'));
        Assert.IsFalse(OfficeUpdateAvailableDlg.AdminNonBreaking.Visible, StrSubstNo(FieldIsDisplayedErr, 'AdminNonBreaking'));
        Assert.IsTrue(OfficeUpdateAvailableDlg.AdminBreaking.Visible, StrSubstNo(FieldNotDisplayedErr, 'AdminBreaking'));
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployUpdateNowPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        OfficeUpdateAvailableDlg.UpgradeNow.DrillDown;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployPromptHandler(var Office365Credentials: TestPage "Office 365 Credentials")
    begin
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployUpdateLaterPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        asserterror OfficeUpdateAvailableDlg.UpgradeLater.DrillDown;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure RedeployUserIgnoredPageHandler(var OfficeUpdateAvailableDlg: TestPage "Office Update Available Dlg")
    begin
        OfficeUpdateAvailableDlg.DontShowAgain.SetValue(true);
        asserterror OfficeUpdateAvailableDlg.UpgradeLater.DrillDown;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure RedeployIgnoredMsgHandler(Message: Text[1024])
    begin
    end;
}

