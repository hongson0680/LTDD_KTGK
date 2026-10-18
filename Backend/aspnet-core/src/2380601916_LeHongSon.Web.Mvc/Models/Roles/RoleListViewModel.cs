using LeHongSon.Roles.Dto;
using System.Collections.Generic;

namespace LeHongSon.Web.Models.Roles;

public class RoleListViewModel
{
    public IReadOnlyList<PermissionDto> Permissions { get; set; }
}
