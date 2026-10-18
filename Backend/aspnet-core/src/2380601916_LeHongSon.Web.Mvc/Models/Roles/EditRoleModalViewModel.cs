using Abp.AutoMapper;
using LeHongSon.Roles.Dto;
using LeHongSon.Web.Models.Common;

namespace LeHongSon.Web.Models.Roles;

[AutoMapFrom(typeof(GetRoleForEditOutput))]
public class EditRoleModalViewModel : GetRoleForEditOutput, IPermissionsEditViewModel
{
    public bool HasPermission(FlatPermissionDto permission)
    {
        return GrantedPermissionNames.Contains(permission.Name);
    }
}
