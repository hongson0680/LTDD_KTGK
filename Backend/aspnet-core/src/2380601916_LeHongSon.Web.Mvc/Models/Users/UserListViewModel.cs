using LeHongSon.Roles.Dto;
using System.Collections.Generic;

namespace LeHongSon.Web.Models.Users;

public class UserListViewModel
{
    public IReadOnlyList<RoleDto> Roles { get; set; }
}
