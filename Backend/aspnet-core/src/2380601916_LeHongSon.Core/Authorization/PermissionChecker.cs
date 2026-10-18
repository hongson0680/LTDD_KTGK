using Abp.Authorization;
using LeHongSon.Authorization.Roles;
using LeHongSon.Authorization.Users;

namespace LeHongSon.Authorization;

public class PermissionChecker : PermissionChecker<Role, User>
{
    public PermissionChecker(UserManager userManager)
        : base(userManager)
    {
    }
}
