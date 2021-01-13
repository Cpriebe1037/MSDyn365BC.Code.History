codeunit 1808 "Assisted Setup Upgrade Tag"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerCompanyUpgradeTags', '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(GetDeleteAssistedSetupTag());
    end;

    procedure GetDeleteAssistedSetupTag(): Code[250]
    begin
        exit('MS-309177-DeleteAssistedSetupToRecreateRecords-20190808');
    end;
}