# Mass email is org_owner only, so organizers and event staff can't spam delegates.
class EmailBlastPolicy < ApplicationPolicy
  %i[index? show? create? update? destroy? test? deliver? preview?].each do |action|
    define_method(action) { user.present? && user.is_org_owner? }
  end
end
