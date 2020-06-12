function(newDoc, oldDoc, userCtx, secObj) {
    function is_admin(userCtx, secObj) {
        if (userCtx.roles.indexOf('_admin') !== -1) {
            return true; /* server admin */
        }

        if (secObj && secObj.admins && secObj.admins.names) {
            if (secObj.admins.names.indexOf(userCtx.name) !== -1) {
                return true; /* db admin by name */
            }
        }

        if (secObj && secObj.admins && secObj.admins.roles) {
            let db_roles = secObj.admins.roles;
            for (let idx = 0; idx < userCtx.roles.length; idx++) {
                let user_role = userCtx.roles[idx];
                if (db_roles.indexOf(user_role) !== -1) {
                    return true; /* db admin by role */
                }
            }
        }
        return false;
    }

    if (!is_admin(userCtx, secObj)) {
        throw({
            unauthorized: 'This database is read-only to non-admins'
        });
    }
}
