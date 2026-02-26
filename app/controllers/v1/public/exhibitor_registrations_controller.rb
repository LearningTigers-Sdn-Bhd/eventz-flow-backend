# frozen_string_literal: true

module V1
  module Public
    class ExhibitorRegistrationsController < ApplicationController
      class ZoneSoldOutError < StandardError; end

      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def booth_prices
        event = Event.friendly.find(params[:event_slug])

        prices = event.exhibitor_booth_prices.includes(:exhibitor_zone_quota).order(:booth_type, :label)
        zone_sold_map = zone_sold_counts(event)

        render json: {
          success: true,
          data: prices.map do |price|
            zone_quota = price.exhibitor_zone_quota&.quota
            zone_sold_count = zone_sold_map[price.exhibitor_zone_quota_id].to_i
            zone_remaining = zone_quota.nil? ? nil : [zone_quota - zone_sold_count, 0].max

            {
              id: price.id,
              booth_type: price.booth_type,
              zone: price.zone,
              exhibitor_zone_quota_id: price.exhibitor_zone_quota_id,
              label: price.label,
              price: price.price,
              zone_quota: zone_quota,
              zone_sold_count: zone_sold_count,
              zone_remaining: zone_remaining,
              zone_available: zone_quota.nil? || zone_remaining.positive?,
            }
          end,
        }
      end

      def status
        event = Event.friendly.find(params[:event_slug])
        email = params[:email].to_s.strip.downcase

        if email.blank?
          return render json: { success: false, message: "Email is required" }, status: :unprocessable_content
        end

        exhibitor_kit = find_existing_registration(event: event, email: email)

        render json: { success: true, data: serialize_registration_status(exhibitor_kit) }
      end

      def create
        event = Event.friendly.find(params[:event_slug])

        unless event.published? && event.use_exhibitor_kit?
          return render json: {
            success: false,
            message: "Registration is not open for this event",
          }, status: :unprocessable_content
        end

        email = registration_params[:pic_email_address].to_s.strip.downcase
        if email.blank?
          return render json: { success: false, message: "Email is required" }, status: :unprocessable_content
        end

        existing_kit = find_existing_registration(event: event, email: email)
        if existing_kit.present?
          return render json: {
            success: true,
            data: serialize_existing_registration(existing_kit),
          }, status: :ok
        end

        booth_price = event.exhibitor_booth_prices.find(params[:exhibitor_booth_price_id])
        exhibitor_kit = create_registration!(event: event, booth_price: booth_price)

        render json: {
          success: true,
          data: {
            exhibitor_kit_id: exhibitor_kit.id,
            price: exhibitor_kit.amount_paid,
            payment_option: registration_params[:payment_option].to_s == "later" ? "later" : "now",
            payment_required: registration_params[:payment_option].to_s != "later",
            exhibitor_kit: serialize_exhibitor_kit(exhibitor_kit),
          },
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { success: false, errors: e.record.errors.full_messages }, status: :unprocessable_content
      rescue ZoneSoldOutError
        render json: { success: false, message: "Selected zone is sold out" }, status: :unprocessable_content
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: "Event or booth price not found" }, status: :not_found
      end

      private

      def create_registration!(event:, booth_price:)
        ActiveRecord::Base.transaction do
          user = find_or_create_vendor_user!
          upsert_vendor_profile!(user)

          event.with_lock do
            exhibitor = Exhibitor.find_by(event: event, vendor: user)

            if exhibitor&.exhibitor_kit.present?
              return exhibitor.exhibitor_kit
            end

            ensure_zone_capacity!(booth_price: booth_price)

            if exhibitor.present?
              return exhibitor.create_exhibitor_kit!(build_exhibitor_kit_attributes(booth_price))
            end

            exhibitor = Exhibitor.new(event: event, vendor: user)
            exhibitor.build_exhibitor_kit(build_exhibitor_kit_attributes(booth_price))
            exhibitor.save!
            exhibitor.exhibitor_kit
          end
        end
      end

      def find_or_create_vendor_user!
        email = registration_params[:pic_email_address].to_s.strip.downcase

        user = User.find_or_initialize_by(email: email)

        if user.persisted?
          user.assign_attributes(
            full_name: registration_params[:pic_full_name],
            phone: registration_params[:pic_contact_number],
            role: :vendor,
            email_verified_at: user.email_verified_at || Time.current,
          )
          user.save! if user.changed?
          return user
        end

        password = "OgseSabah123"

        user.assign_attributes(
          full_name: registration_params[:pic_full_name],
          phone: registration_params[:pic_contact_number],
          role: :vendor,
          password: password,
          password_confirmation: password,
          email_verified_at: Time.current,
        )
        user.save!
        user
      end

      def build_exhibitor_kit_attributes(booth_price)
        custom_fields_data = (registration_params[:custom_fields_data] || {}).to_h
        payment_option = registration_params[:payment_option].to_s == "later" ? "later" : "now"

        {
          company_name: registration_params[:company_name],
          company_address: registration_params[:company_address],
          name_on_fascia: registration_params[:name_on_fascia],
          pic_full_name: registration_params[:pic_full_name],
          pic_position: registration_params[:pic_position],
          pic_contact_number: registration_params[:pic_contact_number],
          pic_email_address: registration_params[:pic_email_address],
          country: registration_params[:country],
          custom_fields_data: custom_fields_data.merge(payment_option: payment_option),
          exhibitor_booth_price: booth_price,
          booth_type: booth_price.booth_type,
          amount_paid: booth_price.price,
          payment_status: :unpaid,
        }
      end

      def registration_params
        params.permit(
          :company_name,
          :company_address,
          :name_on_fascia,
          :pic_full_name,
          :pic_position,
          :pic_contact_number,
          :pic_email_address,
          :country,
          :product_category,
          :payment_option,
          :exhibitor_booth_price_id,
          custom_fields_data: {},
        )
      end

      def upsert_vendor_profile!(user)
        profile = user.vendor_profile || user.reload.vendor_profile || user.build_vendor_profile

        profile.assign_attributes(
          category: registration_params[:product_category],
          person_in_charge: registration_params[:pic_full_name],
          address: registration_params[:company_address],
        )

        profile.save! if profile.new_record? || profile.changed?
      end

      def serialize_exhibitor_kit(exhibitor_kit)
        {
          id: exhibitor_kit.id,
          company_name: exhibitor_kit.company_name,
          name_on_fascia: exhibitor_kit.name_on_fascia,
          pic_full_name: exhibitor_kit.pic_full_name,
          pic_position: exhibitor_kit.pic_position,
          pic_email_address: exhibitor_kit.pic_email_address,
          country: exhibitor_kit.country,
          booth_type: exhibitor_kit.booth_type,
          amount_paid: exhibitor_kit.amount_paid,
          payment_status: exhibitor_kit.payment_status,
          payment_option: exhibitor_kit.custom_fields_data&.dig("payment_option") || "now",
          exhibitor_booth_price_id: exhibitor_kit.exhibitor_booth_price_id,
          custom_fields_data: exhibitor_kit.custom_fields_data || {},
        }
      end

      def serialize_registration_status(exhibitor_kit)
        return {
          has_registered: false,
          exhibitor_kit_id: nil,
          payment_status: nil,
          company_name: nil,
          name_on_fascia: nil,
          pic_email_address: nil,
          pic_full_name: nil,
          pic_position: nil,
          pic_contact_number: nil,
          country: nil,
          preferred_booth_location: nil,
          other_services: [],
          booth_label: nil,
          price: nil,
        } if exhibitor_kit.blank?

        {
          has_registered: true,
          exhibitor_kit_id: exhibitor_kit.id,
          payment_status: exhibitor_kit.payment_status,
          company_name: exhibitor_kit.company_name,
          name_on_fascia: exhibitor_kit.name_on_fascia,
          pic_email_address: exhibitor_kit.pic_email_address,
          pic_full_name: exhibitor_kit.pic_full_name,
          pic_position: exhibitor_kit.pic_position,
          pic_contact_number: exhibitor_kit.pic_contact_number,
          country: exhibitor_kit.country,
          preferred_booth_location: exhibitor_kit.custom_fields_data&.dig("preferred_booth_location"),
          other_services: exhibitor_kit.custom_fields_data&.dig("other_services") || [],
          booth_label: exhibitor_kit.exhibitor_booth_price&.label,
          price: exhibitor_kit.amount_paid,
        }
      end

      def serialize_existing_registration(exhibitor_kit)
        {
          already_registered: true,
          exhibitor_kit_id: exhibitor_kit.id,
          price: exhibitor_kit.amount_paid,
          payment_option: exhibitor_kit.custom_fields_data&.dig("payment_option") || "now",
          payment_required: exhibitor_kit.payment_status != "paid",
          exhibitor_kit: serialize_exhibitor_kit(exhibitor_kit),
        }
      end

      def find_existing_registration(event:, email:)
        event.exhibitors
          .joins(:exhibitor_kit, :vendor)
          .where("LOWER(exhibitor_kits.pic_email_address) = :email OR LOWER(users.email) = :email", email: email)
          .includes(exhibitor_kit: :exhibitor_booth_price)
          .map(&:exhibitor_kit)
          .compact
          .max_by(&:created_at)
      end

      def ensure_zone_capacity!(booth_price:)
        zone_quota = booth_price.exhibitor_zone_quota
        return if zone_quota.nil?

        sold_count = zone_sold_count(zone_quota.id)
        raise ZoneSoldOutError if sold_count >= zone_quota.quota
      end

      def zone_sold_counts(event)
        ExhibitorKit
          .joins(:event_vendor, :exhibitor_booth_price)
          .where(event_vendors: { event_id: event.id, type: "Exhibitor" })
          .group("exhibitor_booth_prices.exhibitor_zone_quota_id")
          .count
      end

      def zone_sold_count(zone_quota_id)
        ExhibitorKit
          .joins(:event_vendor, :exhibitor_booth_price)
          .where(exhibitor_booth_prices: { exhibitor_zone_quota_id: zone_quota_id })
          .count
      end
    end
  end
end
