class VoucherPolicy < ApplicationPolicy

	class Scope < Scope
		def resolve
			if user&.is_org_owner? || user&.is_organizer?
				scope.all
			elsif user&.is_vendor?
				scope.where(vendor_id: user.id).or(scope.where(status: 'published'))
			else
				scope.where(status: 'published')
			end
		end
	end

	def create?
		return false unless user&.is_org_owner? || user&.is_organizer? || user&.is_vendor?

		# Vendors can only create vouchers for themselves
		if user.is_vendor?
			record.vendor_id == user.id
		else
			true
		end
	end

	def show?
		return true if user&.is_org_owner? || user&.is_organizer?

		return true if user&.is_vendor? && user.id == record.vendor_id

		record.status == 'published'
	end

	def update?
		edit?
	end

	def edit?
		user&.is_org_owner? || user&.is_organizer? || (user&.is_vendor? && user.id == record.vendor_id)
	end

	def destroy?
		edit?
	end
end
