using LeHongSon.Roles.Dto;
using System.Collections.Generic;

namespace LeHongSon.Web.Models.Common;

public interface IPermissionsEditViewModel
{
    List<FlatPermissionDto> Permissions { get; set; }
}