using Abp.Authorization;
using Abp.Localization;
using Abp.MultiTenancy;

namespace LeHongSon.Authorization;

public class LeHongSonAuthorizationProvider : AuthorizationProvider
{
    public override void SetPermissions(IPermissionDefinitionContext context)
    {
        context.CreatePermission(PermissionNames.Pages_Users, L("Users"));
        context.CreatePermission(PermissionNames.Pages_Users_Activation, L("UsersActivation"));
        context.CreatePermission(PermissionNames.Pages_Roles, L("Roles"));
        context.CreatePermission(PermissionNames.Pages_Tenants, L("Tenants"), multiTenancySides: MultiTenancySides.Host);

        var exams = context.CreatePermission(PermissionNames.Pages_Exams, L("Exams"));
        exams.CreateChildPermission(PermissionNames.Pages_Exams_Create, L("ExamsCreate"));
        exams.CreateChildPermission(PermissionNames.Pages_Exams_Edit, L("ExamsEdit"));
        exams.CreateChildPermission(PermissionNames.Pages_Exams_Delete, L("ExamsDelete"));
        exams.CreateChildPermission(PermissionNames.Pages_Exams_Publish, L("ExamsPublish"));
    }

    private static ILocalizableString L(string name)
    {
        return new LocalizableString(name, LeHongSonConsts.LocalizationSourceName);
    }
}
