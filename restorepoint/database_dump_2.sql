--
-- PostgreSQL database dump
--

\restrict p4f8cbVVW63YZ4ZncntFEDpIauBmR7NjJB1a4GaS4MvdCUtKWyJwEXcv7B2mEMq

-- Dumped from database version 18.0 (Debian 18.0-1.pgdg13+3)
-- Dumped by pg_dump version 18.0 (Debian 18.0-1.pgdg13+3)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.api_keys (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying,
    key_hash character varying NOT NULL,
    last_used_at timestamp(6) without time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.api_keys OWNER TO lttechteam;

--
-- Name: api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.api_keys_id_seq OWNER TO lttechteam;

--
-- Name: api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.ar_internal_metadata OWNER TO lttechteam;

--
-- Name: email_verifications; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.email_verifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    hashed_code character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.email_verifications OWNER TO lttechteam;

--
-- Name: email_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.email_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.email_verifications_id_seq OWNER TO lttechteam;

--
-- Name: email_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.email_verifications_id_seq OWNED BY public.email_verifications.id;


--
-- Name: event_assignments; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.event_assignments (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.event_assignments OWNER TO lttechteam;

--
-- Name: event_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.event_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_assignments_id_seq OWNER TO lttechteam;

--
-- Name: event_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.event_assignments_id_seq OWNED BY public.event_assignments.id;


--
-- Name: event_exhibition_contractors; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.event_exhibition_contractors (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    exhibition_contractor_profile_id bigint CONSTRAINT event_exhibition_contractor_exhibition_contractor_prof_not_null NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.event_exhibition_contractors OWNER TO lttechteam;

--
-- Name: event_exhibition_contractors_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.event_exhibition_contractors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_exhibition_contractors_id_seq OWNER TO lttechteam;

--
-- Name: event_exhibition_contractors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.event_exhibition_contractors_id_seq OWNED BY public.event_exhibition_contractors.id;


--
-- Name: event_location_members; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.event_location_members (
    id bigint NOT NULL,
    event_location_id bigint NOT NULL,
    member_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.event_location_members OWNER TO lttechteam;

--
-- Name: event_location_members_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.event_location_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_location_members_id_seq OWNER TO lttechteam;

--
-- Name: event_location_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.event_location_members_id_seq OWNED BY public.event_location_members.id;


--
-- Name: event_locations; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.event_locations (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    name character varying NOT NULL,
    scan_limit integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    is_unlimited boolean DEFAULT false NOT NULL,
    floor character varying,
    location_details jsonb DEFAULT '{}'::jsonb
);


ALTER TABLE public.event_locations OWNER TO lttechteam;

--
-- Name: event_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.event_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_locations_id_seq OWNER TO lttechteam;

--
-- Name: event_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.event_locations_id_seq OWNED BY public.event_locations.id;


--
-- Name: event_vendors; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.event_vendors (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    redirect_url character varying,
    poster_url character varying,
    type character varying NOT NULL,
    exhibitor_owner_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    qr_url character varying
);


ALTER TABLE public.event_vendors OWNER TO lttechteam;

--
-- Name: event_vendors_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.event_vendors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_vendors_id_seq OWNER TO lttechteam;

--
-- Name: event_vendors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.event_vendors_id_seq OWNED BY public.event_vendors.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    status integer DEFAULT 0 NOT NULL,
    multiple_scans boolean DEFAULT false NOT NULL,
    start_date timestamp(6) without time zone,
    end_date timestamp(6) without time zone,
    webhook_url character varying,
    labels_data jsonb DEFAULT '{}'::jsonb,
    visibility boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    payment_status integer DEFAULT 0,
    price numeric(8,2) DEFAULT 0.0,
    published boolean DEFAULT false NOT NULL,
    use_ticket boolean DEFAULT true NOT NULL,
    deleted_at timestamp(6) without time zone,
    slug character varying,
    use_exhibitor_kit boolean DEFAULT false NOT NULL
);


ALTER TABLE public.events OWNER TO lttechteam;

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.events_id_seq OWNER TO lttechteam;

--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: exhibition_contractor_profiles; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.exhibition_contractor_profiles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    company_name character varying,
    contact_person character varying,
    contact_email character varying,
    contact_phone character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.exhibition_contractor_profiles OWNER TO lttechteam;

--
-- Name: exhibition_contractor_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.exhibition_contractor_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.exhibition_contractor_profiles_id_seq OWNER TO lttechteam;

--
-- Name: exhibition_contractor_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.exhibition_contractor_profiles_id_seq OWNED BY public.exhibition_contractor_profiles.id;


--
-- Name: exhibitor_kits; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.exhibitor_kits (
    id bigint NOT NULL,
    event_vendor_id bigint NOT NULL,
    booth_number character varying,
    booth_type integer,
    booth_dimensions character varying,
    side_wall_left_required boolean DEFAULT false,
    side_wall_right_required boolean DEFAULT false,
    name_on_fascia character varying,
    fascia_upgrade_required boolean DEFAULT false,
    company_name character varying,
    company_address text,
    pic_full_name character varying,
    pic_contact_number character varying,
    pic_email_address character varying,
    extra_crew_count integer DEFAULT 0,
    special_requirements text,
    digital_brochure_link character varying,
    qr_code_url character varying,
    contractor_company_name character varying,
    contractor_pic_name character varying,
    contractor_pic_contact character varying,
    stand_design_file_url character varying,
    furniture_requests json,
    electrical_requests json,
    printing_orders json,
    indemnity_signed boolean DEFAULT false,
    indemnity_document_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    payment_status integer DEFAULT 0,
    amount_paid numeric(10,2),
    payment_note text,
    indemnity_link character varying
);


ALTER TABLE public.exhibitor_kits OWNER TO lttechteam;

--
-- Name: exhibitor_kits_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.exhibitor_kits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.exhibitor_kits_id_seq OWNER TO lttechteam;

--
-- Name: exhibitor_kits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.exhibitor_kits_id_seq OWNED BY public.exhibitor_kits.id;


--
-- Name: exhibitor_owners; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.exhibitor_owners (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    contact_email character varying,
    contact_phone character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.exhibitor_owners OWNER TO lttechteam;

--
-- Name: exhibitor_owners_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.exhibitor_owners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.exhibitor_owners_id_seq OWNER TO lttechteam;

--
-- Name: exhibitor_owners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.exhibitor_owners_id_seq OWNED BY public.exhibitor_owners.id;


--
-- Name: exhibitor_team_members; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.exhibitor_team_members (
    id bigint NOT NULL,
    exhibitor_kit_id bigint NOT NULL,
    full_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.exhibitor_team_members OWNER TO lttechteam;

--
-- Name: exhibitor_team_members_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.exhibitor_team_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.exhibitor_team_members_id_seq OWNER TO lttechteam;

--
-- Name: exhibitor_team_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.exhibitor_team_members_id_seq OWNED BY public.exhibitor_team_members.id;


--
-- Name: export_logs; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.export_logs (
    id bigint NOT NULL,
    type character varying,
    sheet_path character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    event_id bigint NOT NULL
);


ALTER TABLE public.export_logs OWNER TO lttechteam;

--
-- Name: export_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.export_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.export_logs_id_seq OWNER TO lttechteam;

--
-- Name: export_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.export_logs_id_seq OWNED BY public.export_logs.id;


--
-- Name: group_affiliates; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.group_affiliates (
    id bigint NOT NULL,
    group_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.group_affiliates OWNER TO lttechteam;

--
-- Name: group_affiliates_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.group_affiliates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.group_affiliates_id_seq OWNER TO lttechteam;

--
-- Name: group_affiliates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.group_affiliates_id_seq OWNED BY public.group_affiliates.id;


--
-- Name: group_members; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.group_members (
    id bigint NOT NULL,
    group_id bigint NOT NULL,
    user_id bigint NOT NULL,
    has_manager_access boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.group_members OWNER TO lttechteam;

--
-- Name: group_members_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.group_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.group_members_id_seq OWNER TO lttechteam;

--
-- Name: group_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.group_members_id_seq OWNED BY public.group_members.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.groups (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.groups OWNER TO lttechteam;

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.groups_id_seq OWNER TO lttechteam;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.groups_id_seq OWNED BY public.groups.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.orders OWNER TO lttechteam;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO lttechteam;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: password_resets; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.password_resets (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_digest character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.password_resets OWNER TO lttechteam;

--
-- Name: password_resets_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.password_resets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.password_resets_id_seq OWNER TO lttechteam;

--
-- Name: password_resets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.password_resets_id_seq OWNED BY public.password_resets.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO lttechteam;

--
-- Name: ticket_types; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.ticket_types (
    id bigint NOT NULL,
    event_id bigint,
    name character varying NOT NULL,
    price numeric(8,2) DEFAULT 0.0 NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    max_per_order integer DEFAULT 10 NOT NULL,
    sale_starts_at timestamp(6) without time zone,
    sale_ends_at timestamp(6) without time zone,
    status integer DEFAULT 0,
    hidden boolean DEFAULT false,
    custom_fields_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.ticket_types OWNER TO lttechteam;

--
-- Name: ticket_types_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.ticket_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ticket_types_id_seq OWNER TO lttechteam;

--
-- Name: ticket_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.ticket_types_id_seq OWNED BY public.ticket_types.id;


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.tickets (
    id bigint NOT NULL,
    public_id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id bigint NOT NULL,
    ticket_type_id bigint NOT NULL,
    user_id bigint,
    attendee_name character varying NOT NULL,
    attendee_email character varying,
    attendee_phone character varying,
    checked_in boolean DEFAULT false NOT NULL,
    check_in_at timestamp(6) without time zone,
    scanned_by_id bigint,
    status integer DEFAULT 0 NOT NULL,
    payment_status integer DEFAULT 0 NOT NULL,
    payment_screenshot_url character varying,
    transaction_id character varying,
    payment_method character varying,
    custom_fields_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    attendee_email_norm character varying,
    attendee_phone_norm character varying,
    attendee_name_norm character varying,
    deleted_at timestamp(6) without time zone
);


ALTER TABLE public.tickets OWNER TO lttechteam;

--
-- Name: tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.tickets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tickets_id_seq OWNER TO lttechteam;

--
-- Name: tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.tickets_id_seq OWNED BY public.tickets.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying,
    password_digest character varying,
    full_name character varying,
    phone character varying,
    role integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    jti character varying NOT NULL,
    email_verified_at timestamp(6) without time zone,
    created_by_id bigint
);


ALTER TABLE public.users OWNER TO lttechteam;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO lttechteam;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: vendor_profiles; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.vendor_profiles (
    id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    image_path character varying,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    category character varying,
    person_in_charge character varying,
    address text,
    notes text
);


ALTER TABLE public.vendor_profiles OWNER TO lttechteam;

--
-- Name: vendor_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.vendor_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vendor_profiles_id_seq OWNER TO lttechteam;

--
-- Name: vendor_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.vendor_profiles_id_seq OWNED BY public.vendor_profiles.id;


--
-- Name: visitor_vendor_stamps; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.visitor_vendor_stamps (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    event_vendor_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.visitor_vendor_stamps OWNER TO lttechteam;

--
-- Name: visitor_vendor_stamps_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.visitor_vendor_stamps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.visitor_vendor_stamps_id_seq OWNER TO lttechteam;

--
-- Name: visitor_vendor_stamps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.visitor_vendor_stamps_id_seq OWNED BY public.visitor_vendor_stamps.id;


--
-- Name: visitors; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.visitors (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    public_id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name character varying,
    gender character varying,
    age integer,
    phone character varying,
    email character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.visitors OWNER TO lttechteam;

--
-- Name: visitors_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.visitors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.visitors_id_seq OWNER TO lttechteam;

--
-- Name: visitors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.visitors_id_seq OWNED BY public.visitors.id;


--
-- Name: voucher_redemption_logs; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.voucher_redemption_logs (
    id bigint NOT NULL,
    voucher_id bigint NOT NULL,
    redeemer_staff_id bigint,
    redemption_timestamp timestamp(6) without time zone,
    redemption_location character varying,
    redemption_status character varying,
    transaction_gross_amount numeric(10,2),
    discount_applied_value numeric(10,2),
    transaction_net_amount numeric(10,2),
    cancellation_timestamp timestamp(6) without time zone,
    cancellation_reason text,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    redeemer_id bigint,
    redeemer_type character varying
);


ALTER TABLE public.voucher_redemption_logs OWNER TO lttechteam;

--
-- Name: voucher_redemption_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.voucher_redemption_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.voucher_redemption_logs_id_seq OWNER TO lttechteam;

--
-- Name: voucher_redemption_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.voucher_redemption_logs_id_seq OWNED BY public.voucher_redemption_logs.id;


--
-- Name: voucher_usages; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.voucher_usages (
    id bigint CONSTRAINT user_voucher_usages_id_not_null NOT NULL,
    voucher_id bigint CONSTRAINT user_voucher_usages_voucher_id_not_null NOT NULL,
    redemption_count integer,
    first_view_timestamp timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT user_voucher_usages_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT user_voucher_usages_updated_at_not_null NOT NULL,
    redeemer_id bigint,
    redeemer_type smallint
);


ALTER TABLE public.voucher_usages OWNER TO lttechteam;

--
-- Name: voucher_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.voucher_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.voucher_usages_id_seq OWNER TO lttechteam;

--
-- Name: voucher_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.voucher_usages_id_seq OWNED BY public.voucher_usages.id;


--
-- Name: vouchers; Type: TABLE; Schema: public; Owner: lttechteam
--

CREATE TABLE public.vouchers (
    id bigint NOT NULL,
    title character varying,
    voucher_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    description text,
    vendor_id bigint,
    event_id bigint,
    voucher_code character varying,
    start_date date,
    end_date date,
    start_time time without time zone,
    end_time time without time zone,
    total_redemption_available integer,
    redeemed_count integer,
    max_redemptions_per_user integer,
    user_role_restriction text,
    voucher_value numeric(10,2),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    image_path character varying,
    voucher_category character varying,
    status integer DEFAULT 0,
    voucher_type integer,
    is_unlimited boolean DEFAULT false NOT NULL
);


ALTER TABLE public.vouchers OWNER TO lttechteam;

--
-- Name: vouchers_id_seq; Type: SEQUENCE; Schema: public; Owner: lttechteam
--

CREATE SEQUENCE public.vouchers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vouchers_id_seq OWNER TO lttechteam;

--
-- Name: vouchers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lttechteam
--

ALTER SEQUENCE public.vouchers_id_seq OWNED BY public.vouchers.id;


--
-- Name: api_keys id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);


--
-- Name: email_verifications id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.email_verifications ALTER COLUMN id SET DEFAULT nextval('public.email_verifications_id_seq'::regclass);


--
-- Name: event_assignments id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_assignments ALTER COLUMN id SET DEFAULT nextval('public.event_assignments_id_seq'::regclass);


--
-- Name: event_exhibition_contractors id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_exhibition_contractors ALTER COLUMN id SET DEFAULT nextval('public.event_exhibition_contractors_id_seq'::regclass);


--
-- Name: event_location_members id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_location_members ALTER COLUMN id SET DEFAULT nextval('public.event_location_members_id_seq'::regclass);


--
-- Name: event_locations id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_locations ALTER COLUMN id SET DEFAULT nextval('public.event_locations_id_seq'::regclass);


--
-- Name: event_vendors id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_vendors ALTER COLUMN id SET DEFAULT nextval('public.event_vendors_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: exhibition_contractor_profiles id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibition_contractor_profiles ALTER COLUMN id SET DEFAULT nextval('public.exhibition_contractor_profiles_id_seq'::regclass);


--
-- Name: exhibitor_kits id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_kits ALTER COLUMN id SET DEFAULT nextval('public.exhibitor_kits_id_seq'::regclass);


--
-- Name: exhibitor_owners id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_owners ALTER COLUMN id SET DEFAULT nextval('public.exhibitor_owners_id_seq'::regclass);


--
-- Name: exhibitor_team_members id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_team_members ALTER COLUMN id SET DEFAULT nextval('public.exhibitor_team_members_id_seq'::regclass);


--
-- Name: export_logs id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.export_logs ALTER COLUMN id SET DEFAULT nextval('public.export_logs_id_seq'::regclass);


--
-- Name: group_affiliates id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_affiliates ALTER COLUMN id SET DEFAULT nextval('public.group_affiliates_id_seq'::regclass);


--
-- Name: group_members id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_members ALTER COLUMN id SET DEFAULT nextval('public.group_members_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.groups ALTER COLUMN id SET DEFAULT nextval('public.groups_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: password_resets id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.password_resets ALTER COLUMN id SET DEFAULT nextval('public.password_resets_id_seq'::regclass);


--
-- Name: ticket_types id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.ticket_types ALTER COLUMN id SET DEFAULT nextval('public.ticket_types_id_seq'::regclass);


--
-- Name: tickets id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.tickets ALTER COLUMN id SET DEFAULT nextval('public.tickets_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: vendor_profiles id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vendor_profiles ALTER COLUMN id SET DEFAULT nextval('public.vendor_profiles_id_seq'::regclass);


--
-- Name: visitor_vendor_stamps id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitor_vendor_stamps ALTER COLUMN id SET DEFAULT nextval('public.visitor_vendor_stamps_id_seq'::regclass);


--
-- Name: visitors id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitors ALTER COLUMN id SET DEFAULT nextval('public.visitors_id_seq'::regclass);


--
-- Name: voucher_redemption_logs id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_redemption_logs ALTER COLUMN id SET DEFAULT nextval('public.voucher_redemption_logs_id_seq'::regclass);


--
-- Name: voucher_usages id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_usages ALTER COLUMN id SET DEFAULT nextval('public.voucher_usages_id_seq'::regclass);


--
-- Name: vouchers id; Type: DEFAULT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vouchers ALTER COLUMN id SET DEFAULT nextval('public.vouchers_id_seq'::regclass);


--
-- Data for Name: api_keys; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.api_keys (id, user_id, name, key_hash, last_used_at, is_active, created_at, updated_at) FROM stdin;
2	10	Test	$2a$12$vmzxfLjxz4nITa4vTsBpk.iJu4TRcRuFJcaFGnuy/LmmR1SnpA8Xa	2025-10-31 06:46:09.405493	t	2025-10-31 06:40:58.03775	2025-10-31 06:46:09.407853
3	10	EventzFlow Workflow 2	$2a$12$miAvGOme92MH.JEQxhn2E.XlQm8VL.g7yp8tOJYkRzJIpaAB14t2O	2025-11-28 14:02:11.208746	t	2025-11-28 01:06:53.242243	2025-11-28 14:02:11.209741
1	10	EventzFlow workflow	$2a$12$r667QxP/NT/y/QdWfEizi.9YOEGRnGSfiL1TTSk9YXd8jp1DZTVHC	2025-11-26 07:33:48.154513	t	2025-10-31 05:10:36.613813	2025-11-26 07:33:48.242185
\.


--
-- Data for Name: ar_internal_metadata; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.ar_internal_metadata (key, value, created_at, updated_at) FROM stdin;
environment	production	2025-10-27 04:03:05.673607	2025-10-27 04:03:05.673612
schema_sha1	c017388719fc7478f4e9fd57dfdd1cf8d953bd94	2025-10-27 04:03:05.682871	2025-10-27 04:03:05.683186
\.


--
-- Data for Name: email_verifications; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.email_verifications (id, user_id, hashed_code, expires_at, revoked_at, created_at, updated_at) FROM stdin;
2	20	$2a$12$qi8QKH36y9yan31DZto8AeEK.uk/uoiGZzLN7L26hoOnPS2m98D.a	2025-10-28 02:26:18.95545	2025-10-28 02:30:28.104075	2025-10-28 02:11:18.955914	2025-10-28 02:11:18.955914
4	20	$2a$12$wPeBtk4LxsUYTEUWsNd2VuwsdtrjnC8IDPUmE0d13SCA23VaM8RcG	2025-10-28 02:45:28.31904	2025-10-28 02:31:22.303298	2025-10-28 02:30:28.319682	2025-10-28 02:31:22.304271
5	22	$2a$12$uV5hMS29sroyGefWG2wrP.2zi0jVPOGQqB02QQBaEmBf9czrxZNty	2025-10-28 05:16:43.628582	2025-10-28 05:12:40.119482	2025-10-28 05:01:43.630375	2025-10-28 05:01:43.630375
6	22	$2a$12$daI/f1NXimVvLvJghuXoOew/1wwkGpkT1hW84uw88RoVFHtj26Ur6	2025-10-28 05:27:40.332144	2025-10-28 07:06:43.435075	2025-10-28 05:12:40.332728	2025-10-28 05:12:40.332728
3	21	$2a$12$afFrbRHe7LFe0i56YraE1.Yo1UMQrhAj4BtPROOP0VGxISbVlgOC2	2025-10-28 02:26:37.672172	2025-10-28 07:18:33.014549	2025-10-28 02:11:37.672605	2025-10-28 02:11:37.672605
8	21	$2a$12$RHFgjj1l7h34RFa4MARuJeMMd06JLoj48Yt5mFye63ZdTi/bPUyaC	2025-10-28 07:33:33.23611	2025-10-28 07:18:38.678591	2025-10-28 07:18:33.236847	2025-10-28 07:18:33.236847
9	21	$2a$12$YYSZ/e7e1dArZ9EA7STsguxOv4D54NtWXjpin1ETQSRQkZIy6eofG	2025-10-28 07:33:38.907428	2025-10-28 07:18:44.653418	2025-10-28 07:18:38.908238	2025-10-28 07:18:38.908238
10	21	$2a$12$ktKPMnhVGe6qUwUnhQgvqOElqfQ6uiosFm.PKMQ4MkuRCUQBjxm32	2025-10-28 07:33:44.866007	2025-10-28 07:18:51.193116	2025-10-28 07:18:44.866577	2025-10-28 07:18:44.866577
11	21	$2a$12$12LJIKc1HLnEY4EJMUyyxeO9kHIXzbCSvLHWDKrpe2vefOFwl61bK	2025-10-28 07:33:51.411689	2025-10-28 07:24:49.304315	2025-10-28 07:18:51.412196	2025-10-28 07:18:51.412196
12	21	$2a$12$b1n34tj.o1/bOhQJGCkoxeBdPOw6AaEDNhWKaBYTAkLzhiA.wcdQK	2025-10-28 07:39:49.533367	2025-10-28 07:24:54.985645	2025-10-28 07:24:49.53416	2025-10-28 07:24:49.53416
13	21	$2a$12$npaz8QR8eYBNazXi5hTjlep8jZ13LSSmvGp/oB3UxgtMmyY.7rirC	2025-10-28 07:39:55.204136	2025-10-28 07:25:00.933579	2025-10-28 07:24:55.20468	2025-10-28 07:24:55.20468
14	21	$2a$12$hAu8yEJgxvsALHZmei.Vwuboe2Xj9BsF.VCUWt0xt7ctW9O6i4zMe	2025-10-28 07:40:01.192268	2025-10-28 07:25:07.522318	2025-10-28 07:25:01.192923	2025-10-28 07:25:01.192923
15	21	$2a$12$ksRHzMt.TKzfdn167rZd8.aYYzuH/Mc66ItSSz3kNFkP4Q9i2ftjW	2025-10-28 07:40:07.745518	2025-10-28 07:31:43.714905	2025-10-28 07:25:07.74601	2025-10-28 07:25:07.74601
16	21	$2a$12$a4D6lmygfqY0fPwY9F2G9.ZfpZ7Ir/2yHq2DWo3ALaOWRVg9H9DI6	2025-10-28 07:46:43.943851	2025-10-28 08:13:28.170234	2025-10-28 07:31:43.944553	2025-10-28 07:31:43.944553
17	21	$2a$12$lcV5etZerO.cvbC3VyihTONJekQPsMprdufioG9K.3Cm89G.tW9BK	2025-10-28 08:28:28.395789	\N	2025-10-28 08:13:28.396335	2025-10-28 08:13:28.396335
7	22	$2a$12$FxFyVCH7ckNxi1LOwleIVeyeT0DhK1X.4raOiVYCTDv0UL.6LIJPe	2025-10-28 07:21:43.854925	2025-10-29 01:34:47.21733	2025-10-28 07:06:43.867789	2025-10-28 07:06:43.867789
18	22	$2a$12$beE8fqccgpBbdKjcGQcn4ejGrDgCCUIRxnJBdG2At0QoGafg4r/V6	2025-10-29 01:49:47.510871	2025-10-29 05:54:13.330286	2025-10-29 01:34:47.521647	2025-10-29 01:34:47.521647
19	22	$2a$12$Fs1.d2ZbO0Nf/5SiQRkBwuP9PBFy2hLhh9ZrZ2hakembM1g2Pk6hW	2025-10-29 06:09:13.546023	2025-10-29 05:54:47.848047	2025-10-29 05:54:13.546714	2025-10-29 05:54:47.8492
1	19	$2a$12$ZqoJ2AbvHnG7vaE4b93SQeT500VnIXkblbf1JY7ObY1Let45dketW	2025-10-28 02:25:40.604535	2025-10-30 00:14:07.396873	2025-10-28 02:10:40.605067	2025-10-28 02:10:40.605067
20	19	$2a$12$yX23Vxp4Yq/ch99jHaUsFu1.9yP.rzJ9ByuAy.DxsNbVUgflZkqQm	2025-10-30 00:29:07.751275	\N	2025-10-30 00:14:07.772085	2025-10-30 00:14:07.772085
21	32	$2a$12$vEXJ8jOni1TgfpsvA/5OseziJI06NKeeNAbO1l5.RDi32LicbwOmq	2025-11-07 00:06:17.968556	2025-11-06 23:51:38.558336	2025-11-06 23:51:17.969216	2025-11-06 23:51:38.559313
22	38	$2a$12$nABQOgwYEW33ytQpdudCEeQCQXCcCenS8I6Is9qiwT8jFN8KTBYDO	2025-12-02 02:56:15.473428	\N	2025-12-02 02:41:15.475974	2025-12-02 02:41:15.475974
\.


--
-- Data for Name: event_assignments; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.event_assignments (id, event_id, user_id, role, created_at, updated_at) FROM stdin;
1	1	10	event_admin	2025-10-30 00:58:51.881385	2025-10-30 00:58:51.881385
2	2	10	event_admin	2025-10-30 04:24:53.844579	2025-10-30 04:24:53.844579
3	1	23	event_team_member	2025-11-05 02:54:22.987959	2025-11-05 02:54:22.987959
4	1	24	event_team_member	2025-11-05 02:54:30.896674	2025-11-05 02:54:30.896674
5	1	25	event_team_member	2025-11-05 02:54:35.094309	2025-11-05 02:54:35.094309
6	1	26	event_team_member	2025-11-05 02:54:38.012398	2025-11-05 02:54:38.012398
7	1	27	event_team_member	2025-11-05 02:54:40.884957	2025-11-05 02:54:40.884957
8	1	28	event_team_member	2025-11-05 02:54:43.899689	2025-11-05 02:54:43.899689
9	1	29	event_team_member	2025-11-05 02:54:46.496647	2025-11-05 02:54:46.496647
10	1	30	event_team_member	2025-11-05 02:54:49.290137	2025-11-05 02:54:49.290137
11	1	31	event_team_member	2025-11-05 02:54:51.709071	2025-11-05 02:54:51.709071
12	2	34	event_admin	2025-11-25 05:37:33.720941	2025-11-25 05:37:33.720941
13	3	10	event_admin	2025-11-28 00:59:10.661575	2025-11-28 00:59:10.661575
14	2	36	event_team_member	2025-11-28 08:10:40.987311	2025-11-28 08:10:40.987311
\.


--
-- Data for Name: event_exhibition_contractors; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.event_exhibition_contractors (id, event_id, exhibition_contractor_profile_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: event_location_members; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.event_location_members (id, event_location_id, member_id, created_at, updated_at) FROM stdin;
1	1	23	2025-11-05 02:55:33.765179	2025-11-05 02:55:33.765179
2	1	24	2025-11-05 02:55:33.773737	2025-11-05 02:55:33.773737
3	1	25	2025-11-05 02:55:33.779504	2025-11-05 02:55:33.779504
4	1	26	2025-11-05 02:55:33.78478	2025-11-05 02:55:33.78478
5	1	27	2025-11-05 02:55:33.788266	2025-11-05 02:55:33.788266
6	1	28	2025-11-05 02:55:33.792032	2025-11-05 02:55:33.792032
7	1	29	2025-11-05 02:55:33.802519	2025-11-05 02:55:33.802519
8	1	30	2025-11-05 02:55:33.808131	2025-11-05 02:55:33.808131
9	1	31	2025-11-05 02:55:33.813436	2025-11-05 02:55:33.813436
\.


--
-- Data for Name: event_locations; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.event_locations (id, event_id, name, scan_limit, created_at, updated_at, is_unlimited, floor, location_details) FROM stdin;
1	1	Registration Counter	1	2025-10-30 01:01:46.327881	2025-10-30 01:01:46.327881	f	\N	{}
\.


--
-- Data for Name: event_vendors; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.event_vendors (id, event_id, vendor_id, redirect_url, poster_url, type, exhibitor_owner_id, created_at, updated_at, qr_url) FROM stdin;
1	2	33	\N	\N	Merchant	\N	2025-11-25 05:29:00.014251	2025-11-25 05:29:00.014251	\N
2	2	35	\N	\N	Merchant	\N	2025-11-25 05:38:22.993838	2025-11-25 05:38:22.993838	\N
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.events (id, title, description, status, multiple_scans, start_date, end_date, webhook_url, labels_data, visibility, created_at, updated_at, payment_status, price, published, use_ticket, deleted_at, slug, use_exhibitor_kit) FROM stdin;
3	PUMM Malacca 2025 Dinner	\N	1	f	2025-12-18 16:00:00	2025-12-19 16:00:00		{}	t	2025-11-28 00:59:10.60562	2025-11-28 01:01:04.308503	0	0.00	f	f	\N	pumm-malaysia-role-model-recognition-2026-dinner	f
2	PUMM Malaysia Role Model Recognition 2026 Dinner	\N	1	f	2025-11-28 10:30:00	2025-11-29 14:40:00		{"label_1": "Label 1"}	t	2025-10-30 04:24:53.831989	2025-11-28 01:01:19.923698	0	0.00	f	f	\N	pumm-dinner-2025	f
1	SME EXPO International & AI Summit 2025	The SME EXPO International 2025 is Sabah’s premier platform to showcase, connect, and grow businesses across industries. Over 3 days, entrepreneurs, innovators, and industry leaders will gather under one roof to explore opportunities, discover innovations, and drive collaborations.	1	f	2025-11-07 00:00:00	2025-11-09 09:00:00	https://webhook.saleschatalyst.com/webhook/6908575d1b9845c02d44d252	{"role": "Role", "company": "Company", "position": "Position", "coupon_referral": "Coupon/Referral", "business_industry": "Business Industry", "print_exhibitor_tag": "Print Exhibitor Tag?"}	t	2025-10-30 00:58:51.847734	2025-11-06 02:28:57.089925	0	0.00	f	t	\N	\N	f
\.


--
-- Data for Name: exhibition_contractor_profiles; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.exhibition_contractor_profiles (id, user_id, company_name, contact_person, contact_email, contact_phone, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: exhibitor_kits; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.exhibitor_kits (id, event_vendor_id, booth_number, booth_type, booth_dimensions, side_wall_left_required, side_wall_right_required, name_on_fascia, fascia_upgrade_required, company_name, company_address, pic_full_name, pic_contact_number, pic_email_address, extra_crew_count, special_requirements, digital_brochure_link, qr_code_url, contractor_company_name, contractor_pic_name, contractor_pic_contact, stand_design_file_url, furniture_requests, electrical_requests, printing_orders, indemnity_signed, indemnity_document_url, created_at, updated_at, payment_status, amount_paid, payment_note, indemnity_link) FROM stdin;
\.


--
-- Data for Name: exhibitor_owners; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.exhibitor_owners (id, name, description, contact_email, contact_phone, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: exhibitor_team_members; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.exhibitor_team_members (id, exhibitor_kit_id, full_name, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: export_logs; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.export_logs (id, type, sheet_path, created_at, updated_at, event_id) FROM stdin;
1	ticket-list	/rails/storage/exports/tickets-1-20251104_055106.xlsx	2025-11-04 05:51:06.909551	2025-11-04 05:51:06.909551	1
2	ticket-list	/rails/storage/exports/tickets-1-20251105_030311.xlsx	2025-11-05 03:03:11.582901	2025-11-05 03:03:11.582901	1
3	ticket-list	/rails/storage/exports/tickets-1-20251105_030449.xlsx	2025-11-05 03:04:49.541519	2025-11-05 03:04:49.541519	1
4	ticket-list	/rails/storage/exports/tickets-1-20251106_014546.xlsx	2025-11-06 01:45:47.020308	2025-11-06 01:45:47.020308	1
5	ticket-list	/rails/storage/exports/tickets-1-20251106_235124.xlsx	2025-11-06 23:51:24.815522	2025-11-06 23:51:24.815522	1
6	ticket-list	/rails/storage/exports/tickets-1-20251106_235228.xlsx	2025-11-06 23:52:28.795686	2025-11-06 23:52:28.795686	1
7	ticket-list	/rails/storage/exports/tickets-1-20251107_002951.xlsx	2025-11-07 00:29:51.347136	2025-11-07 00:29:51.347136	1
8	ticket-list	/rails/storage/exports/tickets-1-20251107_003531.xlsx	2025-11-07 00:35:31.45472	2025-11-07 00:35:31.45472	1
9	ticket-list	/rails/storage/exports/tickets-1-20251107_003939.xlsx	2025-11-07 00:39:39.54398	2025-11-07 00:39:39.54398	1
10	ticket-list	/rails/storage/exports/tickets-1-20251107_004026.xlsx	2025-11-07 00:40:27.092155	2025-11-07 00:40:27.092155	1
11	ticket-list	/rails/storage/exports/tickets-1-20251107_004500.xlsx	2025-11-07 00:45:00.500926	2025-11-07 00:45:00.500926	1
12	ticket-list	/rails/storage/exports/tickets-1-20251107_004655.xlsx	2025-11-07 00:46:55.794035	2025-11-07 00:46:55.794035	1
13	ticket-list	/rails/storage/exports/tickets-1-20251107_004708.xlsx	2025-11-07 00:47:08.913146	2025-11-07 00:47:08.913146	1
14	ticket-list	/rails/storage/exports/tickets-1-20251107_004909.xlsx	2025-11-07 00:49:09.720071	2025-11-07 00:49:09.720071	1
15	ticket-list	/rails/storage/exports/tickets-1-20251107_074510.xlsx	2025-11-07 07:45:11.056262	2025-11-07 07:45:11.056262	1
16	ticket-list	/rails/storage/exports/tickets-1-20251120_224136.xlsx	2025-11-20 22:41:36.431913	2025-11-20 22:41:36.431913	1
\.


--
-- Data for Name: group_affiliates; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.group_affiliates (id, group_id, vendor_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: group_members; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.group_members (id, group_id, user_id, has_manager_access, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.groups (id, name, description, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.orders (id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: password_resets; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.password_resets (id, user_id, token_digest, expires_at, revoked_at, created_at, updated_at) FROM stdin;
1	19	$2a$12$kg6XYfdY9oCkfsvrkQ6Q8OUgPF.1Xb.9aqXX3HYO5OfwE2nuaV.3y	2025-10-30 01:06:37.384691	2025-10-30 00:40:26.813102	2025-10-30 00:36:37.388854	2025-10-30 00:36:37.388854
2	19	$2a$12$uHyLng3FnKPvtK5eYB3yKut33Q1ZtQL.yvvCKlohPBaOlIGhZpKay	2025-10-30 01:10:26.818661	2025-10-30 00:46:13.694936	2025-10-30 00:40:26.823064	2025-10-30 00:46:13.695472
3	19	$2a$12$QuqLoYYWpETUjFFvFI8bQOhMI9NIUGGBLmeiK0IvTwMkyh5rLVDcu	2025-10-30 02:35:03.286308	2025-10-30 02:06:19.507844	2025-10-30 02:05:03.287812	2025-10-30 02:06:19.508291
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.schema_migrations (version) FROM stdin;
20251018044425
20251017031740
20251017031230
20251016054022
20251016051828
20251016031027
20251016030833
20251016024953
20251015070801
20251015070207
20251015020729
20251013040332
20251013024138
20251013001340
20251013001339
20251013001338
20251027030100
20251027045423
20251027065417
20251027065436
20251029090000
20251030013251
20251030090000
20251103031034
20251103033834
20251103050000
20251103050500
20251103061500
20251112082840
20251112082841
20251112082842
20251112082843
20251114022046
20251114023804
20251114023813
20251114025626
20251117094742
20251117095633
20251117095634
20251118000000
20251118044853
20251119040009
20251120002009
20251120044824
20251120064239
20251120075307
20251120090411
20251124022348
20251124095909
20251124100303
20251126015633
20251126015723
20251127113323
20251127113325
20251127113326
\.


--
-- Data for Name: ticket_types; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.ticket_types (id, event_id, name, price, quantity, max_per_order, sale_starts_at, sale_ends_at, status, hidden, custom_fields_data, created_at, updated_at) FROM stdin;
1	1	AI Summit (English) Day 1	0.00	0	1	\N	\N	1	f	{}	2025-10-30 01:18:17.226797	2025-10-30 01:18:17.226797
2	1	Exhibitor	0.00	999	1	\N	\N	1	f	{}	2025-10-31 06:41:25.789453	2025-10-31 06:41:25.789453
3	1	AI Summit (Chinese) Day 2	0.00	500	1	\N	\N	1	f	{}	2025-11-01 10:12:53.247664	2025-11-01 10:12:53.247664
4	1	Play To Win	0.00	100	1	\N	\N	1	f	{}	2025-11-01 16:31:07.884467	2025-11-01 16:31:07.884467
5	1	Invited Delegate	0.00	100	1	\N	\N	1	f	{}	2025-11-03 08:53:55.138098	2025-11-03 08:53:55.138098
6	1	Speaker	0.00	100	1	\N	\N	1	f	{}	2025-11-03 08:54:40.622994	2025-11-03 08:54:40.622994
7	1	VIP	0.00	100	1	\N	\N	1	f	{}	2025-11-03 10:42:42.88389	2025-11-03 10:42:42.88389
8	1	Visitor	0.00	1000	1	\N	\N	1	f	{}	2025-11-04 02:39:17.633791	2025-11-04 02:39:17.633791
9	1	VVIP	0.00	100	1	\N	\N	1	f	{}	2025-11-04 05:19:14.404972	2025-11-04 05:19:14.404972
11	1	SME EXPO Day 2	0.00	100	1	\N	\N	1	f	{}	2025-11-07 23:29:56.151627	2025-11-07 23:29:56.151627
\.


--
-- Data for Name: tickets; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.tickets (id, public_id, event_id, ticket_type_id, user_id, attendee_name, attendee_email, attendee_phone, checked_in, check_in_at, scanned_by_id, status, payment_status, payment_screenshot_url, transaction_id, payment_method, custom_fields_data, created_at, updated_at, attendee_email_norm, attendee_phone_norm, attendee_name_norm, deleted_at) FROM stdin;
4	f2d2adca-bd87-42b5-b82f-c616af5c717c	1	1	\N	Theophilus Wong	\N	012-2045400	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Samenta Sarawak", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 01:57:03.029582	2025-11-06 02:23:46.264265	\N	0122045400	theophilus wong	\N
268	78d050c0-b693-4127-bfc7-ed8349845aea	1	7	\N	Francis Tan Ban Thien	\N	\N	t	2025-11-05 09:54:15.192371	29	1	1	\N	\N	\N	{"role": "VIP", "company": "ALLIANCE BANK MALAYSIA BERHAD", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.038816	2025-11-05 09:54:15.193016	\N	\N	francis tan ban thien	\N
269	18613210-15bc-4b8a-9d80-aaa443fa8feb	1	7	\N	Adlis Khairil Sazli Mohd Zaini	\N	\N	t	2025-11-05 09:56:02.283468	29	1	1	\N	\N	\N	{"role": "VIP", "company": "BANK NEGARA MALAYSIA CAWANGAN KK", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.048667	2025-11-05 09:56:02.284203	\N	\N	adlis khairil sazli mohd zaini	\N
270	298ad5ab-7164-4fd3-9672-27ea7dfbf5b4	1	7	\N	Kevin George Ukang	\N	\N	t	2025-11-05 10:28:02.738305	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SEDIA", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.067154	2025-11-05 10:28:02.739446	\N	\N	kevin george ukang	\N
272	9d1fd0d2-3d52-441d-992a-82001fd4cdd4	1	7	\N	Frederick Mah	\N	\N	t	2025-11-05 10:03:51.903264	29	1	1	\N	\N	\N	{"role": "VIP", "company": "MONTFORT YOUTH TRAINING CENTRE", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.10664	2025-11-05 10:03:51.903869	\N	\N	frederick mah	\N
275	69ab3773-28d5-4976-95e0-8dcc8f51a885	1	7	\N	Jamilah Lee Nyuk Choon	\N	\N	t	2025-11-05 08:30:38.058988	26	1	1	\N	\N	\N	{"role": "VIP", "company": "KORPORASI PEMBANGUNAN DESA", "position": "GENERAL MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.144014	2025-11-05 08:30:38.060475	\N	\N	jamilah lee nyuk choon	\N
276	45c15910-dac5-4178-9696-c23b6b19d3b7	1	7	\N	Datuk Adeline Leong	\N	\N	t	2025-11-05 10:39:40.938521	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "INTER EDUCATION CONSULT SDN BHD", "position": "EXECUTIVE DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.153388	2025-11-05 10:39:40.939117	\N	\N	datuk adeline leong	\N
279	b8b01b37-8c3c-4b4c-988b-35b57eebe131	1	7	\N	Hiew Chee Wah	\N	012345678	t	2025-11-05 11:12:46.099575	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "SRIKOM GROUP", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.176554	2025-11-05 11:12:46.100299	\N	012345678	hiew chee wah	\N
281	82a77bb0-4c2e-422e-88b6-a430270ecccd	1	7	\N	Dr Prashanth Kumar	\N	\N	t	2025-11-05 10:26:04.449781	23	1	1	\N	\N	\N	{"role": "VIP", "company": "GAMUDA AI ACADEMY", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.195504	2025-11-05 10:26:04.450648	\N	\N	dr prashanth kumar	\N
283	1f8ba85d-08cb-4bae-855b-7eeb1fad4ae5	1	7	\N	Joseph Tan	\N	\N	t	2025-11-05 10:20:33.899907	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "REGAS EV SABAH SDN.BHD", "position": "DEALER PRINCIPAL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.219997	2025-11-05 10:20:33.900838	\N	\N	joseph tan	\N
284	386651f5-68a8-468d-b085-44601c3d7476	1	7	\N	Datuk Sr. Lifred Wong	\N	\N	t	2025-11-05 10:25:37.903471	23	1	1	\N	\N	\N	{"role": "VIP", "company": "DBKK", "position": "DIRECTOR GENERAL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.227149	2025-11-05 10:25:37.904007	\N	\N	datuk sr. lifred wong	\N
285	0cfc0d8c-f78b-4ce1-9f3c-8ba688b377e7	1	7	\N	Jackson Ting Jack Hing	\N	\N	t	2025-11-05 10:05:29.358005	29	1	1	\N	\N	\N	{"role": "VIP", "company": "D'SUNLIT SDN.BHD", "position": "MANAGING DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.238829	2025-11-05 10:05:29.358642	\N	\N	jackson ting jack hing	\N
1680	c50598fb-4655-4547-8a58-89a637fa7444	1	1	\N	Bibi	Bibikayap@yahoo.com	60146748776	t	2025-11-08 08:21:59.069175	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 08:21:59.069175	2025-11-12 01:14:06.168419	bibikayap@yahoo.com	60146748776	bibi	\N
287	35267ded-985a-4d64-b111-dd7539947a8f	1	7	\N	Datuk Chin Wee Yee	\N	\N	t	2025-11-05 07:14:05.672685	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "MALAYSIA-CHINA CHAMBER OF COMMERCE", "position": "VICE PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.25662	2025-11-05 07:14:05.673465	\N	\N	datuk chin wee yee	\N
288	1f42559d-bc64-49b8-9524-60b6756a92af	1	7	\N	Ms Betty Bridget Epin	\N	\N	t	2025-11-05 10:24:33.492105	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH WOMEN ENTREPRENEUR & PROFESSIONALS ASSOCIATION", "position": "PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.263122	2025-11-05 10:24:33.49297	\N	\N	ms betty bridget epin	\N
291	9ddfd892-9dcf-4e8f-b882-8f8db7eb2308	1	7	\N	Joshua Ho Yee En, Jp	\N	\N	t	2025-11-05 11:36:25.74173	30	1	1	\N	\N	\N	{"role": "VIP", "company": "YAYASAN SABAH GROUP", "position": "FINANCIAL CONTROLLER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.292683	2025-11-05 11:36:25.742474	\N	\N	joshua ho yee en, jp	\N
292	c3bb4c06-ca3b-471c-9a0a-12e76c4cdbff	1	7	\N	Erica R Jun Erh Wong	\N	\N	t	2025-11-05 10:25:07.905639	23	1	1	\N	\N	\N	{"role": "VIP", "company": "BANK NEGARA MALAYSIA CAWANGAN KK", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.303174	2025-11-05 10:25:07.906264	\N	\N	erica r jun erh wong	\N
294	2c963144-9fa0-4d9b-9272-b9ac1a83de63	1	7	\N	Shaffiq Mizwar	\N	\N	t	2025-11-05 10:27:16.954315	23	1	1	\N	\N	\N	{"role": "VIP", "company": "TERAJU, SABAH", "position": "EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.355044	2025-11-05 10:27:16.955063	\N	\N	shaffiq mizwar	\N
375	ce7e3bbd-5e4a-4ec1-9937-cf378b123096	1	7	\N	Azman Nain	\N	\N	t	2025-11-05 09:46:37.552633	29	1	1	\N	\N	\N	{"role": "VIP", "company": "Sabah International Convention Centre", "position": "Director of Convention Services", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 06:01:32.97804	2025-11-05 09:46:37.553178	\N	\N	azman nain	\N
672	9bd462cc-cfd8-4beb-86ed-c61222e7567f	1	1	\N	Izah Muhilin	izah@sogipport.com.my	60168262647	t	2025-11-07 00:00:52.088204	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SOGDC", "position": "Asst. HR Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:58:38.627658	2025-11-07 00:00:52.08883	izah@sogipport.com.my	60168262647	izah muhilin	\N
533	46bb035d-2021-4c7a-9141-b04e27ff3edb	1	7	\N	Ms Lynette Hoo	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "POIC SABAH SDN BHD", "position": "DEPUTY GROUP CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 03:28:18.063573	2025-11-06 03:28:18.063573	\N	\N	ms lynette hoo	\N
734	72f39fff-cebf-40e5-8c7e-32e412867aa6	1	1	\N	Kevin Wong	wwjds0808@gmail.com	60146568116	t	2025-11-07 00:14:23.244978	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "wwjds0808@gmail.com", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:13:01.966042	2025-11-07 00:14:23.245584	wwjds0808@gmail.com	60146568116	kevin wong	\N
754	b7320fcd-f89a-4257-a593-af27afb8fadb	1	1	\N	Klein How	klein@jackhan-intl.com	6738276336	t	2025-11-07 00:18:14.208756	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Jackhan Furniture Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:17:54.038017	2025-11-07 00:18:14.209372	klein@jackhan-intl.com	6738276336	klein how	\N
2025	4d787379-98c4-4234-aa48-866597a56faa	1	1	\N	Steven Chua	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 06:46:12.00574	2025-11-11 06:59:21.921829	\N	\N	steven chua	\N
1176	9371cef1-753b-4dce-83eb-83a37d9b0ba0	1	1	\N	Norina Awang	bongsurina89@gmail.com	60168653919	t	2025-11-07 09:17:33.355826	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Asoib313 Enterprise ", "position": "Manager"}	2025-11-07 09:17:13.12095	2025-11-07 09:17:33.356737	bongsurina89@gmail.com	60168653919	norina awang	\N
1283	98200746-0eeb-436d-a1cc-2ca23c3131b2	1	3	\N	Valentina Kang Yu Rou	\N	60178183279	t	2025-11-08 00:54:50.462035	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "STKK", "position": "Student"}	2025-11-08 00:54:29.491961	2025-11-08 00:54:50.462647	\N	60178183279	valentina kang yu rou	\N
9	c67b8c32-4151-43eb-a863-38f40d5bf37b	1	1	\N	Donna Koh	\N	016-8337388	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Discovery Tours (Sabah) Sdn Bhd", "position": "Senior Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:45:26.889042	2025-11-01 09:46:16.774885	\N	0168337388	donna koh	\N
298	02020888-a0a3-4025-bab9-7a6756af2821	1	7	\N	Izah Muhilin Madani	\N	\N	t	2025-11-05 07:10:43.570752	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "SODGC", "position": "ASSISTANT MANAGER HR & ADMIN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.464087	2025-11-05 07:10:43.571441	\N	\N	izah muhilin madani	\N
301	226f4e30-fabd-4471-b59b-b96180b2f30e	1	7	\N	Dr Vincent Chiew	\N	\N	t	2025-11-05 11:21:07.665842	30	1	1	\N	\N	\N	{"role": "VIP", "company": "GAME DEFINER (MALAYSIA)", "position": "FOUNDER & CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.522486	2025-11-05 11:22:09.704046	\N	\N	dr vincent chiew	\N
1787	a74c2ebc-b5b9-4d91-ba95-ae1ebf052fea	1	1	\N	Hafizah Jumat	bibiefza97@gmail.com	60196926619	t	2025-11-09 04:07:49.295188	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-09 04:07:49.295188	2025-11-12 01:14:11.37805	bibiefza97@gmail.com	60196926619	hafizah jumat	\N
307	a36cdd2f-600b-4480-ad0a-1bd713bced46	1	7	\N	Evans Beh	\N	\N	t	2025-11-05 12:14:57.358203	30	1	1	\N	\N	\N	{"role": "VIP", "company": "Rejoice Moment", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.636404	2025-11-05 12:14:57.35893	\N	\N	evans beh	\N
308	887fd09f-ef9f-4dfc-8e89-93391885aad9	1	7	\N	Kantlyn Chan	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.648982	2025-11-04 07:54:58.923742	\N	\N	kantlyn chan	\N
311	4e5c19b1-4e90-4b71-87ee-2e1f389a5093	1	7	\N	Fong Ming San	\N	01133130996	t	2025-11-05 11:54:56.937975	30	1	1	\N	\N	\N	{"role": "VIP", "company": "Sabah Employers Association", "position": "Secretary General", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.707694	2025-11-05 11:56:04.425314	\N	01133130996	fong ming san	\N
313	461248b0-c2bd-4ada-b17c-005cfff06819	1	7	\N	Sally Lee	\N	0192825388	t	2025-11-05 11:15:25.356012	25	1	1	\N	\N	\N	{"role": "VIP", "company": "B PROJECT ACADEMY HOLDING SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.742294	2025-11-05 11:15:25.356664	\N	0192825388	sally lee	\N
315	2f2b8e2e-7736-4703-a22d-193d3829548c	1	7	\N	Datuk Stephen Sampil	\N	\N	t	2025-11-05 11:56:58.493327	30	1	1	\N	\N	\N	{"role": "VIP", "company": "KKCI", "position": "Deputy- President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.769156	2025-11-05 11:56:58.493983	\N	\N	datuk stephen sampil	\N
318	13fb48ca-bf43-44bb-82ab-c37052f24750	1	7	\N	Farah Goh	\N	0128330541	t	2025-11-05 09:45:36.519784	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "Metaverse Solutions", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.806296	2025-11-05 09:45:36.520652	\N	0128330541	farah goh	\N
319	5bc8477e-9a7a-4e4d-b071-23bf76bbd81a	1	7	\N	Raja Chandra Lingham	\N	0198101177	t	2025-11-05 11:39:54.345873	25	1	1	\N	\N	\N	{"role": "VIP", "company": "Sahabat Ikhtisas Sdn Bhd", "position": "Executive Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.823045	2025-11-05 11:39:54.346474	\N	0198101177	raja chandra lingham	\N
320	e312eede-eb9c-4960-8fae-1c6b1f3f51c6	1	7	\N	Arthur Phang	\N	0166728326	t	2025-11-05 11:45:01.501825	25	1	1	\N	\N	\N	{"role": "VIP", "company": "APG REMISIER", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.834663	2025-11-05 11:45:01.503148	\N	0166728326	arthur phang	\N
305	b8d2035e-3cd2-416e-a7d0-5fc1fcac72d1	1	1	\N	Timothy Teo	\N	0123456789	t	2025-11-05 11:42:38.193953	25	1	1	\N	\N	\N	{"role": "VIP", "company": "BORNEO ECO TOUR SDN BHD", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.59621	2025-11-12 01:05:02.408084	\N	0123456789	timothy teo	\N
324	acb01ee6-939a-40bb-8a85-b267a92f17b4	1	9	\N	Yb Datuk Phoong Jin Zhe	\N	\N	t	2025-11-05 10:02:39.228557	\N	1	1	\N	\N	\N	{"role": "", "company": "", "position": "Minister of Industrial Development and Entrepreneurship", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.906026	2025-11-05 10:02:39.22913	\N	\N	yb datuk phoong jin zhe	\N
326	1bf29ab6-da26-46a6-886f-f6af3add79dd	1	9	\N	Dato' George Lim Su Chung	\N	\N	t	2025-11-05 11:35:31.054315	29	1	1	\N	\N	\N	{"role": "ORGANISING CHAIRMAN", "company": "SABAH ENTEPRENEURS TRANSFORMATION ", "position": "FOUNDER & PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.934264	2025-11-05 11:35:31.054959	\N	\N	dato' george lim su chung	\N
327	68850a07-e053-4ff8-abe9-19f3d591a09d	1	6	\N	Dato' Sri Mustapa Bin Mohamed	\N	\N	t	2025-11-05 09:41:54.338276	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "FORMER MINISTER OF MITI", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.949907	2025-11-05 09:41:54.338818	\N	\N	dato' sri mustapa bin mohamed	\N
822	c8e46fc1-c243-40df-8546-75851bd08af2	1	1	\N	Mimi Hong	hongky@teckguan.com	60198335758	t	2025-11-07 03:01:13.221497	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Teck Guan", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:00:49.790825	2025-11-07 03:01:13.222316	hongky@teckguan.com	60198335758	mimi hong	\N
824	1f770177-1c72-4897-9133-1dd1cfe95b34	1	1	\N	Eric Jv Julius	jvjuliuseric@gmail.com	60128240483	t	2025-11-07 03:01:35.42874	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "IPSOS Sdn Bhd", "position": "Survey officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:01:07.386151	2025-11-07 03:01:35.429442	jvjuliuseric@gmail.com	60128240483	eric jv julius	\N
23	215f72b5-50f4-4c38-ab77-c9f0bd263bb4	1	1	\N	Darren Lardizabal	\N	019-8093639	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Green Project Nursery Sdn Bhd", "position": "Founder and CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 04:02:06.987877	2025-11-01 09:30:59.327044	\N	0198093639	darren lardizabal	\N
265	612d86d8-bd92-405f-ab23-90bfbde4c128	1	7	\N	Daniel Wong	\N	0172797877	t	2025-11-05 10:35:43.373879	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "SKAI LAB SDN BHD", "position": "Sabah Distributor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 14:07:57.81727	2025-11-05 10:35:43.374652	\N	0172797877	daniel wong	\N
314	3405fb72-5a6f-401c-82e0-b82db768e69a	1	7	\N	Datuk Ladislaus Maluda	\N	\N	t	2025-11-05 11:40:18.539028	25	1	1	\N	\N	\N	{"role": "VIP", "company": "KKCI", "position": "President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.754686	2025-11-05 11:40:18.539674	\N	\N	datuk ladislaus maluda	\N
1881	b0c25ea5-53b2-4089-95f6-8345335e319c	1	1	\N	Norhabibih	bibiryushu@gmail.com	601125313063	t	2025-11-09 05:31:42.595619	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-09 05:31:42.595619	2025-11-12 01:14:15.749828	bibiryushu@gmail.com	601125313063	norhabibih	\N
323	6cb2ef61-a235-4bcd-b653-528dad4b67ab	1	9	\N	Yb Datuk Chan Foong Hin	\N	\N	t	2025-11-05 09:53:37.170485	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "", "position": "Deputy Minister of Plantation Industries and Commodities", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.893591	2025-11-05 09:53:37.171405	\N	\N	yb datuk chan foong hin	\N
330	89d5c191-517e-4eb3-b724-e6cd1955b88d	1	6	\N	Datuk Josie Lai	\N	\N	t	2025-11-05 09:17:14.500941	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "KEPKAS (MTCE)", "position": "PERMANENT SECRETARY", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.97867	2025-11-05 09:17:14.502158	\N	\N	datuk josie lai	\N
333	df06efc0-510e-4e30-8bce-10e5f288d8b6	1	6	\N	Roshan Thiran	\N	\N	t	2025-11-05 09:10:54.62101	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "LEADERONOMICS", "position": "FOUNDER AND \\"KULI\\"", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.022541	2025-11-05 09:10:54.622006	\N	\N	roshan thiran	\N
335	fa2bac95-d88b-4b6e-8862-6c729b6ce8c6	1	6	\N	Zeth Lim	\N	\N	t	2025-11-06 02:00:21.467107	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "VERDANT SOLAR (MALAYSIA)", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.046984	2025-11-06 02:00:21.467998	\N	\N	zeth lim	\N
336	5670fa70-2590-44ea-b040-6eaed28444cf	1	6	\N	Wook Lee	\N	\N	t	2025-11-06 01:53:05.483204	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "EDENA CAPITAL PARTNERS", "position": "FOUNDER & CHAIRMAN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.056652	2025-11-06 01:53:05.483931	\N	\N	wook lee	\N
338	fc1c0b44-93ac-4fae-aeef-48aed59272f6	1	9	\N	Cally Yau	\N	\N	t	2025-11-05 11:24:55.583271	30	1	1	\N	\N	\N	{"role": "VVIP", "company": "PEOPLELOGY (MALAYSIA)", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.073142	2025-11-05 11:24:55.583889	\N	\N	cally yau	\N
339	4a6f77d3-275e-46ab-95e1-8693d29b92ca	1	6	\N	Chan Kee Siak	\N	\N	t	2025-11-06 01:59:56.947962	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "EXABYTES (MALAYSIA)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.081572	2025-11-06 01:59:56.948635	\N	\N	chan kee siak	\N
341	23bf5890-efb9-4472-bb90-c9bdd7e3e406	1	6	\N	Chhem Siriwat	\N	\N	t	2025-11-05 09:15:03.674166	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "AI FORUM (CAMBODIA)", "position": "PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.103422	2025-11-05 09:15:03.674829	\N	\N	chhem siriwat	\N
344	76bd05d1-44a5-4a41-95af-292a815052d9	1	6	\N	Patrick Klotz	\N	\N	t	2025-11-05 09:13:14.528088	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "SWISSTECH SOLUTIONS (SWITZERLAND)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.125865	2025-11-05 09:13:14.528843	\N	\N	patrick klotz	\N
345	0cd3e3f7-4e00-459c-8516-625459f7fef6	1	6	\N	Prof Witman Hung	\N	\N	t	2025-11-05 09:08:22.124478	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "SHENZHEN ZEBRAS TECHNOLOGY (HONG KONG)", "position": "CO-FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.133332	2025-11-05 09:08:22.12512	\N	\N	prof witman hung	\N
535	d79d7325-cfee-4723-bbc8-ac82f26951b4	1	9	\N	Melissa Wong	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VVIP", "company": "WSG GROUP", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 05:57:10.583228	2025-11-06 05:57:10.583228	\N	\N	melissa wong	\N
347	74ac8f9e-afb1-4fb1-b281-fa632b67a930	1	6	\N	Dr John Loh	\N	\N	t	2025-11-05 09:11:25.717116	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "EMERGING EPC (MALAYSIA)", "position": "DIRECTOR OF OPERATIONS,SUSTAINABILITY & DIGITAL TRANSFORMATION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.153651	2025-11-05 09:11:25.717816	\N	\N	dr john loh	\N
348	d9fc5e7c-9ed7-406d-b1f7-c78fb35ead28	1	6	\N	Ronnie Chong	\N	\N	t	2025-11-05 08:53:12.285854	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "METAVERSE SOLUTIONS (MALAYSIA)", "position": "PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.162836	2025-11-05 08:53:12.286581	\N	\N	ronnie chong	\N
350	ded42da0-349b-4870-a6f0-45cb43106f65	1	6	\N	Maxim Mulyadi	\N	\N	t	2025-11-05 08:59:49.669936	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "CIRCULARITY COACH INTERNATIONAL (INDONESIA)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.190551	2025-11-05 08:59:49.67049	\N	\N	maxim mulyadi	\N
351	b8a01ad0-ba71-4826-98f6-67f12ca739a6	1	6	\N	Kei Chia Kok Wei	\N	\N	t	2025-11-05 09:01:07.053535	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "FINNEX (SINGAPORE)", "position": "FOUNDER & CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.203231	2025-11-05 09:01:07.054296	\N	\N	kei chia kok wei	\N
332	a1628280-1657-42e1-9b0d-6b87dffdad52	1	1	\N	Ybhg. Datuk Thomas Logijin	\N	\N	t	2025-11-06 01:59:02.297387	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "MIDE", "position": "PERMANENT SECRETARY", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.013811	2025-11-12 00:08:50.894655	\N	\N	ybhg. datuk thomas logijin	\N
353	7244beed-3d46-4c61-9c4c-bacf18d1ab19	1	6	\N	Poong Ka Vui	\N	\N	t	2025-11-05 09:01:54.257643	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "REVIEWBAH", "position": "FOUNDER AND CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.233158	2025-11-11 08:18:50.346699	\N	\N	poong ka vui	\N
354	ded9a7ad-f919-4b94-b6ff-15c5425485e5	1	6	\N	Dr Vincent Chew (duplicate Vip)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "GAME DEFINER (MALAYSIA)", "position": "FOUNDER & CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.24296	2025-11-06 02:05:26.181044	\N	\N	dr vincent chew (duplicate vip)	\N
356	7f23b4f8-9fb2-425b-8d98-ab9397f34332	1	6	\N	Debbie Loo	\N	\N	t	2025-11-06 01:53:03.247806	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "KIAN", "position": "CHIEF CULTURE OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.269464	2025-11-06 01:53:03.248862	\N	\N	debbie loo	\N
537	13d6f0b6-2eda-45bd-b63e-68439e9e6fa1	1	9	\N	Voo Yue Han	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VVIP", "company": "DML PRODUCTS (EAST MALAYSIA) SDN BHD", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 05:59:05.867777	2025-11-11 23:53:39.527567	\N	\N	voo yue han	\N
825	13181c2d-1ca1-4b3d-90c1-22e1fab3bc5d	1	1	\N	Nurul Ismah Binti Alias	nurul.ismah97@gmail.com	60146272475	t	2025-11-07 03:13:31.7567	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BTC MAJU HOLDING SDN BHD (BTC FOODS)", "position": "SALES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:01:28.141215	2025-11-07 03:13:31.75721	nurul.ismah97@gmail.com	60146272475	nurul ismah binti alias	\N
826	3f044ed5-9dcc-456d-98c2-dc50faaccb22	1	1	\N	Bilvey Hirrson Zain	bilveyzain@gmail.com	60195275243	t	2025-11-07 03:02:14.483146	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "ipsos sdn bhd", "position": "survey officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:01:51.751118	2025-11-07 03:02:14.48381	bilveyzain@gmail.com	60195275243	bilvey hirrson zain	\N
36	aaf53963-030d-4c9a-bdb9-1b2d9d8c8bb4	1	2	\N	Lz Chong	\N	016-5472517	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "MAKE A DIFFERENT REALITY SDN BHD", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:06:01.985467	2025-11-11 07:20:07.352847	\N	0165472517	lz chong	\N
54	907bca16-9ec4-4073-9b9b-4a808abffcd8	1	2	\N	Raimas	\N	017-8381941	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Raimas Food Industry (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:25:07.110053	2025-11-06 17:24:32.880992	\N	0178381941	raimas	\N
2083	3c029e70-2e1c-4060-b2b5-c11fa92af27e	1	1	\N	Bibiana Bte. Benjamin	\N	\N	t	2025-11-12 01:16:09.832898	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "PRODUCTION CLERK", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-12 01:15:28.020215	2025-11-12 01:16:09.833682	\N	\N	bibiana bte. benjamin	\N
61	7a8b7e71-ce93-4453-aeb5-4380d45ca421	1	2	\N	Khor Kah Siang	\N	016-5365177	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hardkhor Fitness Perkongsian Liabiliti Terhad", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:30:49.971818	2025-11-06 17:23:50.90333	\N	0165365177	khor kah siang	\N
63	bbe32522-9102-4d56-ae11-372824c3425f	1	2	\N	Arunaa	arunaa@ilmulearning.com	013-8100274	t	2025-11-06 23:52:08.241725	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ilmu Institute of Learning", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:33:10.137676	2025-11-06 23:52:08.242402	arunaa@ilmulearning.com	0138100274	arunaa	\N
53	fc9cd28a-7cc0-4b3e-b429-f2862de790fb	1	2	\N	Cleo	\N	016-7706211	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "EMPAM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:25:01.453933	2025-11-06 17:21:57.785882	\N	0167706211	cleo	\N
41	9e40256c-b3ad-47b2-9bda-fd8092bd0caf	1	2	\N	Eugene Teow	\N	019-283 1990	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Dreamztech (M) Berhad", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:12:18.259541	2025-11-06 17:23:43.184997	\N	0192831990	eugene teow	\N
57	087bb331-063b-4eb7-851c-fa77373c36d1	1	2	\N	Reubun Ting	\N	017-6170197	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "ReuTing (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:27:13.706448	2025-11-06 17:23:54.677101	\N	0176170197	reubun ting	\N
261	46d793d0-d45c-4ea5-8ec5-a62d9e5185dd	1	7	\N	Yamashita Yoshito	\N	\N	t	2025-11-05 09:54:11.690268	23	1	1	\N	\N	\N	{"role": "VIP", "company": "CONSULAR OFFICE OF JAPAN KK", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:55:42.663041	2025-11-05 09:54:11.690934	\N	\N	yamashita yoshito	\N
52	2fc6ff20-d9eb-4a96-81f9-ae20ac639cc9	1	2	\N	Kevin Chin	\N	018-2818889	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "KC Media Outlet", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:24:31.816788	2025-11-06 17:23:58.939624	\N	0182818889	kevin chin	\N
2084	562f9478-6daa-4181-901a-0d0607ec429d	1	1	\N	Hisyamuddin Salleh	\N	\N	t	2025-11-12 01:23:36.646646	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CMA ACADEMY", "position": "CONSULTANT"}	2025-11-12 01:23:26.044962	2025-11-12 01:23:36.647594	\N	\N	hisyamuddin salleh	\N
1177	7ccb9d7b-0a2f-4265-b2a7-f2fd0616162d	1	1	\N	Marie	Bern_fire@msn.com	60168109312	t	2025-11-07 09:19:13.094721	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "Borneo International Centre for Arbitration and Mediation ", "position": "Admin "}	2025-11-07 09:19:13.094721	2025-11-07 09:21:40.847146	bern_fire@msn.com	60168109312	marie	\N
367	4b442817-b73b-4cad-9dab-bf037572f821	1	6	\N	Weiss Ang	\N	\N	t	2025-11-06 02:00:37.804207	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "WEISS WISORY (MALAYSIA)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.430497	2025-11-06 02:00:37.804739	\N	\N	weiss ang	\N
368	522a47a0-4461-4d30-a1fb-0d7ad708259c	1	6	\N	Daniel Wong (duplicate Vip)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.447271	2025-11-06 02:06:07.668471	\N	\N	daniel wong (duplicate vip)	\N
369	4993d00b-32e9-497c-9a92-df3338b49356	1	6	\N	Kong Tze How	\N	\N	t	2025-11-06 02:03:46.741859	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "NETQUAS SOFTECH", "position": "CEO AND CTO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.45913	2025-11-06 02:03:46.742612	\N	\N	kong tze how	\N
371	2292ba9f-2087-4877-8a19-db481eeeff78	1	6	\N	Yapp Lip Chau	\N	+60128283537	t	2025-11-06 02:03:43.398108	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "Jesselton Pixel", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.477443	2025-11-06 02:03:43.398702	\N	60128283537	yapp lip chau	\N
536	2d94484c-e0cf-4663-96e1-553e59149e39	1	9	\N	Tammy	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VVIP", "company": "MAXIS BROADBAND SDN.BHD.", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 05:58:21.586261	2025-11-06 05:58:21.586261	\N	\N	tammy	\N
674	96eff0df-913e-4889-ad24-3ec084919e86	1	1	\N	Grace	Gracelim27@live.com	60178199100	t	2025-11-07 00:00:22.125103	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mega Hopes Sales Sdn Bhd ", "position": "Director ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:00:22.125103	2025-11-07 00:00:22.125103	gracelim27@live.com	60178199100	grace	\N
58	6027ef89-02b7-4d32-a040-570a69105c30	1	2	\N	Mohd Hirwan	\N	019-8216020	f	\N	23	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "ChillSmoked SJ (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:27:53.302699	2025-11-06 17:23:47.133632	\N	0198216020	mohd hirwan (f&b)	\N
671	98de2c92-8d27-40e6-8b7b-12331876ec14	1	1	\N	Vellarie June Jeffrey Lungin	vellariejune@sogipport.com.my	60148453585	t	2025-11-07 00:01:11.553466	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SOGDC", "position": "Senior Business Analyst", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:58:37.872213	2025-11-07 00:01:11.554208	vellariejune@sogipport.com.my	60148453585	vellarie june jeffrey lungin	\N
673	a6ab6109-9247-4fa1-b08b-5374f5585761	1	1	\N	Simon Bin Sarong	simonsarong@gmail.com	60168148477	t	2025-11-07 00:02:52.393468	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Clerk", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:00:13.252324	2025-11-07 00:02:52.394064	simonsarong@gmail.com	60168148477	simon bin sarong	\N
255	dc48755c-4ad7-4d24-97d2-58b1355b1534	1	7	\N	Rosnih Binti Othman	\N	\N	t	2025-11-06 01:03:33.225978	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH MAJU JAYA SEKRETARIAT ", "position": "PENGARAH SEKRETARIAT SABAH MAJU JAYA, JABATAN KETUA MENTERI SABAH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:06:06.582102	2025-11-06 01:03:33.22668	\N	\N	rosnih binti othman	\N
2085	31bedb55-cfb4-4d5b-b21b-6f2eaddc1a44	1	1	\N	Sally	\N	\N	t	2025-11-12 01:31:21.195758	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "ONONG RICH ENTERPRISE", "position": "ASSUSTANT MANAGER"}	2025-11-12 01:31:14.254019	2025-11-12 01:31:21.196311	\N	\N	sally	\N
3	e2f3126b-06ec-4a1a-a344-205ea4985b98	1	1	\N	Ts. Muhammad Shafiq Bin Mohd Kamal	\N	012-4187310	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Penang Development Corporation", "position": "System Analyst", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 01:56:25.145034	2025-11-06 02:23:46.255767	\N	0124187310	ts. muhammad shafiq bin mohd kamal	\N
677	d33d5090-d47c-465f-9400-e92ea3bd1fa7	1	1	\N	Yep Weng Hong	kingslynip74@gmail.com	60167782086	t	2025-11-07 00:01:24.407553	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "WHY RAINBOW ENTERPRISE ", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:00:33.930328	2025-11-07 00:01:24.408811	kingslynip74@gmail.com	60167782086	yep weng hong	\N
2087	66578ac1-a0ae-406d-80ef-0e71cdd15fbb	1	1	\N	Charm	\N	\N	t	2025-11-12 01:48:51.484621	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "HUMANCE", "position": "SPOKESPERSON"}	2025-11-12 01:48:36.19193	2025-11-12 01:48:51.485529	\N	\N	charm	\N
229	23d36f87-841f-477c-829f-d683ccdd255d	1	5	\N	Victor Chow	\N	6012-818-6101	t	2025-11-05 08:12:37.136363	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Harmonic Security Engineering Sdn Bhd", "position": "Managing Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:41:38.487697	2025-11-05 08:12:37.137015	\N	60128186101	victor chow	\N
267	4110d9ea-32cc-4076-b1e4-87f575f07b5e	1	7	\N	Datuk Roger Chin	\N	012345678	t	2025-11-05 10:23:03.044604	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH LAW SOCIETY", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.012802	2025-11-05 10:23:03.045295	\N	012345678	datuk roger chin	\N
274	615584d6-9e90-458d-90c5-d8ffa98d56a1	1	7	\N	Kalvin Chua	\N	\N	t	2025-11-05 09:57:25.123332	29	1	1	\N	\N	\N	{"role": "VIP", "company": "EVOPOINT SDN.BHD", "position": "CHIEF TECHNOLOGY SPECIALIST", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.134921	2025-11-05 09:57:25.123924	\N	\N	kalvin chua	\N
380	e186fa35-d482-4adb-bac9-44724b8cdd7e	1	1	\N	Puan Noredah Othman	\N	\N	t	2025-11-05 10:07:50.776178	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "SABAH CONVENTION BUREAU", "position": "CHIEF EXECUTIVE OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.786173	2025-11-12 00:07:23.6772	\N	\N	puan noredah othman	\N
303	e23761ca-f5ed-4c4f-ba17-8473085b80cd	1	7	\N	Dr Deledda Tan	\N	\N	t	2025-11-05 12:00:16.443471	30	1	1	\N	\N	\N	{"role": "VIP", "company": "SME SABAH", "position": "PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.567131	2025-11-12 00:01:59.220508	\N	\N	dr deledda tan	\N
328	65571f3a-b984-4f18-81cc-cbad974d5ba7	1	6	\N	Tan Sri Datuk Seri Panglima Bernard Giluk Dompok	\N	\N	t	2025-11-05 09:03:57.5844	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "SME CORPORATION OF MALAYSIA", "position": "CHAIRMAN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.960938	2025-11-05 09:03:57.585027	\N	\N	tan sri datuk seri panglima bernard giluk dompok	\N
329	3a543e17-ca1a-4dca-aa2c-de80634575db	1	6	\N	Datuk Frederick Kugan (duplicate Vvip)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "SABAH FORESTRY DEPT", "position": "CHIEF CONSERVATOR OF FOREST", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.969007	2025-11-06 02:06:41.980306	\N	\N	datuk frederick kugan (duplicate vvip)	\N
377	e0c8a1c0-d62f-4af7-a19f-dd4083f051b3	1	9	\N	Ken Wong	\N	\N	t	2025-11-05 11:45:50.639069	25	1	1	\N	\N	\N	{"role": "ORGANISING PARTNER", "company": "KIMORA ENTERTAINMENT NETWORK (K.E.N)", "position": "MANAGING DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.760951	2025-11-05 11:45:50.639643	\N	\N	ken wong	\N
379	3c32e843-abdb-47a2-8332-fbecfa26a6c3	1	9	\N	Datuk Dr Roland Chia Ming Shen	\N	\N	t	2025-11-05 11:14:19.341161	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "", "position": "POLITICAL SECRETARY TO CHIEF MINISTER OF SABAH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.779552	2025-11-05 11:14:19.341979	\N	\N	datuk dr roland chia ming shen	\N
376	d557296e-1daf-4367-a67b-b9c34c04d0a8	1	1	\N	Patrick Chiam	\N	60168328116	t	2025-11-05 11:46:11.455612	25	1	1	\N	\N	\N	{"role": "Organising Partner", "company": "PUMM", "position": "SABAH STATE CHAIRMAN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.74243	2025-11-12 00:12:52.444554	\N	60168328116	patrick chiam	\N
679	f162c91e-5a59-460c-bc0f-0ead82762251	1	1	\N	Lim Tiong Chin @ Harold	haroldlim86@yahoo.cim	60138689999	t	2025-11-07 00:01:24.783501	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "TCTL RESOURCES", "position": "Sole Proprietor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:24.783501	2025-11-07 00:01:24.783501	haroldlim86@yahoo.cim	60138689999	lim tiong chin @ harold	\N
383	3c03dd2f-ac9b-4347-b879-4df105baf045	1	7	\N	Dominic Chong	\N	128387678	t	2025-11-05 12:01:54.556687	25	1	1	\N	\N	\N	{"role": "VIP", "company": "CS PHAU & CO", "position": "Partner", "coupon_referral": "VIPSP", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.810435	2025-11-05 12:01:54.557377	\N	128387678	dominic chong	\N
386	6bd1a74e-e47a-4564-a087-05bc8172b03e	1	6	\N	Nur Azre Abdul Aziz	\N	\N	t	2025-11-06 02:01:58.745465	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "Tiktok Shop Malaysia", "position": "Senior Director of Strategic Partnership", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 01:38:32.806017	2025-11-06 02:01:58.746018	\N	\N	nur azre abdul aziz	\N
67	f6879bd0-b76b-4cf4-9210-56b1a062b044	1	2	\N	Franciska Long	\N	018-8749044	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "North Borneo Honey (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:42:52.947876	2025-11-06 17:24:49.849277	\N	0188749044	franciska long	\N
681	7f5c6276-b75c-4ff7-ab22-cd4097ce5b79	1	1	\N	Gabriel Jee Jing	Jackjee95@yahoo.com	60146829419	t	2025-11-07 00:03:08.998971	23	1	1	\N	\N	\N	{"role": "Student", "company": "Kkhs", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:39.67074	2025-11-07 00:03:09.000273	jackjee95@yahoo.com	60146829419	gabriel jee jing	\N
539	52c95d63-d468-4859-8c11-b747fbfb2080	1	1	\N	Mr Tee Chin Kok	\N	\N	t	2025-11-11 23:59:23.850986	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "NHG GLASS INDUSTRIES (SABAH) SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 06:00:54.88642	2025-11-11 23:59:43.269009	\N	\N	mr tee chin kok	\N
304	05a50b68-b98c-46bc-9415-2cd632bf98f4	1	7	\N	Chai Nyit Ngen	\N	\N	t	2025-11-05 12:02:55.217642	30	1	1	\N	\N	\N	{"role": "VIP", "company": "SME SABAH", "position": "VICE PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.580832	2025-11-12 00:01:48.005259	\N	\N	chai nyit ngen	\N
382	613711f2-ecd5-4bb6-9ab9-308642a77469	1	1	\N	Humphrey Ginibun	\N	\N	t	2025-11-05 10:18:22.315481	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "SABAH TOURISM BOARD", "position": "SENIOR MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.801452	2025-11-12 00:52:00.702981	\N	\N	humphrey ginibun	\N
691	d09b0d16-cac7-4f57-b06a-7b1b5ecc8c66	1	1	\N	Audrey Avril	Sheilaavril32@gmail.com	601133233678	t	2025-11-07 00:04:49.594596	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SEAMEX SABAH ASSOCIATION ", "position": "Delegates ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:03:17.329867	2025-11-07 00:04:49.595225	sheilaavril32@gmail.com	601133233678	audrey avril	\N
1287	06fb295a-81e8-43f5-8f20-307dd41fdbe1	1	3	\N	Roger Loo Wei Loong	\N	60166147867	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Proton Melinau inanam", "position": "Sales advisor"}	2025-11-08 00:55:02.789417	2025-11-08 00:55:02.789417	\N	60166147867	roger loo wei loong	\N
85	8a47b645-5991-4268-90d9-9e031a0e8cf4	1	2	\N	Travis Chen	\N	016-8449744	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "T&W Setia Holdings Sdn. Bhd.", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:37:56.055267	2025-11-06 17:24:54.707479	\N	0168449744	travis chen	\N
1288	14ccd5e3-e82d-41da-b9b0-6f181d1dcd87	1	3	\N	Peter Wong Yung Ming	\N	60168442529	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SM Tinggi KK", "position": "Teacher"}	2025-11-08 00:55:10.511933	2025-11-08 00:55:10.511933	\N	60168442529	peter wong yung ming	\N
110	558e5024-45ce-4490-ae6e-1ae1b32982b6	1	4	\N	Erica Joanne Tibok	\N	60109351617	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BORNEO ECO TOUR SDN BHD", "position": "", "coupon_referral": "", "business_industry": "Tourism", "print_exhibitor_tag": ""}	2025-11-02 04:24:22.643291	2025-11-12 01:04:55.112176	\N	60109351617	erica joanne tibok	\N
771	fdee31f3-70dd-42b9-97c8-fa6618e2f589	1	1	\N	Cecelia	\N	\N	t	2025-11-12 01:40:38.537917	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KKIP SDN BHD", "position": "GSVPD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:37:45.400575	2025-11-12 01:41:16.116323	\N	\N	cecelia	\N
1179	fdaa6a4e-e50e-4e24-a5b4-372cdd0b59ff	1	1	\N	Chung Kui Henn	HENN@PLATINUMCITYLOGISTICS.COM.MY	601116012885	t	2025-11-07 09:31:05.096958	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "PLATINUM CITY LOGISTICS SDN BHD ", "position": "MANAGER"}	2025-11-07 09:31:05.096958	2025-11-07 09:31:05.096958	henn@platinumcitylogistics.com.my	601116012885	chung kui henn	\N
83	2eb78e8f-847c-4000-88b1-1d218f1d7c08	1	2	\N	Jalina Binti Jahari	\N	011-19583166	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Yuly Global International Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:37:18.372804	2025-11-06 17:25:48.728334	\N	01119583166	jalina binti jahari	\N
682	0554c928-62b8-4445-9b6b-c57e480e5583	1	1	\N	Norsyazanadia Binti Zaki	Norsyazanadia.Zaki@sabah.gov.my	601126851583	t	2025-11-07 00:07:14.539199	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Kementerian Pelancongan, Kebudayaan dan Alam Sekitar", "position": "Penolong Pegawai Tadbir", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:45.735657	2025-11-07 00:07:14.539841	norsyazanadia.zaki@sabah.gov.my	601126851583	norsyazanadia binti zaki	\N
99	823a83f4-d476-4631-8559-ed91546090cc	1	3	\N	Sherman	\N	0146749133	t	2025-11-07 08:55:04.049221	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "CT Toys Sdn Bhd", "position": "Director ", "coupon_referral": "", "business_industry": "Retailing ", "print_exhibitor_tag": ""}	2025-11-01 10:24:28.211612	2025-11-07 08:55:04.049871	\N	0146749133	sherman	\N
683	699a4706-aa12-4f99-9525-4e7300094230	1	1	\N	Nurulhuda	Nurulhudaz@tarc.edu.my	60122669709	t	2025-11-07 00:05:34.074983	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TAR UMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:51.00353	2025-11-07 00:05:34.07569	nurulhudaz@tarc.edu.my	60122669709	nurulhuda	\N
93	2f2538ed-3c0a-4419-9970-02d23cbd755b	1	1	\N	Michael @ Hing Hock Siong	\N	014-6720355	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "FSI", "position": "Senior Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 09:58:17.408907	2025-11-05 10:25:14.859237	\N	0146720355	michael @ hing hock siong	\N
187	f52a90de-08e7-4b7e-8743-e8833139ca2c	1	3	\N	杜欣诺	\N	0178104321	t	2025-11-07 08:55:57.416095	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "student", "coupon_referral": "", "business_industry": "FINANCE & ACCOUNTING", "print_exhibitor_tag": ""}	2025-11-03 08:04:59.843261	2025-11-07 08:55:57.416836	\N	0178104321	杜欣诺	\N
129	3af2b38f-b807-452c-b314-5a79b603d319	1	1	\N	JOANNA LIEW PYIT CHU	\N	012-8788260	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "CHIEF FINANCIAL OFFICER (CFO)", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:05:05.80453	2025-11-03 06:05:05.80453	\N	0128788260	joanna liew pyit chu	\N
132	4e722863-9ab9-48c6-b16e-19c46e892124	1	1	\N	CHONG CHON YUNG	\N	016-8390001	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "SENIOR SALES & MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:34:55.740826	2025-11-03 06:34:55.740826	\N	0168390001	chong chon yung	\N
139	75d19dce-c262-42eb-ade8-240ef3cec46b	1	1	\N	Benjamin Ang	\N	0168330766	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Kimanis Food Industries", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:52:59.927953	2025-11-03 06:52:59.927953	\N	0168330766	benjamin ang	\N
154	57ecc3fd-6783-488c-b05a-266b702fa459	1	1	\N	Junid Zaidi	\N	012-8876925	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Torr Energy Sdn. Bhd.", "position": "Business Development Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:08:56.19348	2025-11-03 07:08:56.19348	\N	0128876925	junid zaidi	\N
184	eb9bb953-7090-4579-aa9d-fb94ffb77f0a	1	1	\N	Alan Lo	\N	014-3843730	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "FSI", "position": "Secretariat", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:59:55.183173	2025-11-03 07:59:55.183173	\N	0143843730	alan lo	\N
227	b847c76d-ba87-4e82-8b8e-49ad0d541580	1	5	\N	Dr. Chris Daniel Wong	\N	6012-635-6354	t	2025-11-05 08:06:01.278804	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Pemudah", "position": "Director/General Partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:39:39.71941	2025-11-05 08:06:01.279742	\N	60126356354	dr. chris daniel wong	\N
243	67ee70e2-3538-42cb-96e0-bd8a5b1a53e6	1	7	\N	Mohamad Sukry Bin Suile	\N	\N	t	2025-11-05 10:04:54.07016	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH NET", "position": "BUSINESS DEVELOPMENT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:10:20.152423	2025-11-05 10:04:54.070876	\N	\N	mohamad sukry bin suile	\N
692	a5aae7b4-9af8-400b-a374-acc96216f515	1	1	\N	Angelina Tan Xin Nin	ajborneohomes@gmail.com	60168528770	t	2025-11-07 00:06:54.989184	23	1	1	\N	\N	\N	{"role": "Student", "company": "Sabah Tshung Tsin Secondary School", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:03:34.573163	2025-11-07 00:06:54.989903	ajborneohomes@gmail.com	60168528770	angelina tan xin nin	\N
695	ac65064d-b8f8-4848-b297-3da4d06b1462	1	1	\N	Chua Kah Boon	kalvin_chua@evo-point.com	60162398919	t	2025-11-07 00:06:02.219546	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "Evopoint Sdn Bhd", "position": "Chief Technology Specialist", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:04:13.946724	2025-11-07 00:06:02.220509	kalvin_chua@evo-point.com	60162398919	chua kah boon	\N
774	0ac1556d-7fce-4e55-be87-cee47a68edd5	1	1	\N	Yaakob Mahmood	\N	\N	t	2025-11-12 01:07:42.09	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "SOGDC", "position": "COO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:38:48.698432	2025-11-12 01:07:42.090766	\N	\N	yaakob mahmood	\N
201	355dd28e-1e94-4906-b659-08ee99900443	1	3	\N	Cho Yee Shuen	\N	6010-2487278	t	2025-11-07 08:56:24.33314	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Tshung Tsin Secondary School", "position": "Student", "coupon_referral": "", "business_industry": "Student", "print_exhibitor_tag": ""}	2025-11-03 08:30:22.290928	2025-11-07 08:56:24.333713	\N	60102487278	cho yee shuen	\N
228	ca89b6ea-e6d5-4e30-a833-ecf5a60f9ca4	1	5	\N	Chris Ooi	\N	6012-615-7788	t	2025-11-05 08:03:09.596026	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Crigen Resources Bhd", "position": "Sales Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:40:49.702124	2025-11-05 08:03:09.596781	\N	60126157788	chris ooi	\N
541	9d09c60b-cf6b-465e-afc9-897920cf49a0	1	1	\N	Stacy	Qwe@gmail.com	60168135774	t	2025-11-06 10:19:29.591215	23	1	1	\N	\N	\N	{"role": "Student", "company": "Qqq", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 10:15:52.910972	2025-11-06 10:19:29.59239	qwe@gmail.com	60168135774	stacy	\N
1204	b52cd275-9a80-4839-aef5-2e574ab594d6	1	1	\N	Vivian Lee	Vivianleeting95@gmail.com	601151380391	t	2025-11-07 12:33:17.341628	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "Magna Grandview Sdn Bhd", "position": "Admin"}	2025-11-07 12:33:17.341628	2025-11-07 12:33:36.553639	vivianleeting95@gmail.com	601151380391	vivian lee	\N
216	7a52951b-7494-4c04-b10f-cb26207ca481	1	5	\N	Ady Kim	\N	012-8271717	t	2025-11-05 08:19:25.823042	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Biorehab Physiotherapy Centre KK", "position": "Founder", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:02:15.855009	2025-11-05 08:19:25.823587	\N	0128271717	ady kim	\N
230	2fbd51f4-2190-4a41-a778-5b4b88289498	1	7	\N	Rommella @ Genevieve Binti Osmand	\N	\N	t	2025-11-05 10:01:23.429959	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SIRIM", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:43:25.28773	2025-11-05 10:01:23.43066	\N	\N	rommella @ genevieve binti osmand	\N
233	a376a267-62c9-460c-86b1-1b99c6850c14	1	7	\N	Emmanuel Joseph Edward	\N	\N	t	2025-11-05 10:16:36.023336	23	1	1	\N	\N	\N	{"role": "VIP", "company": "HRDF", "position": "HEAD OF UNIT KOTA KINABALU", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:45:44.047864	2025-11-05 10:16:36.023959	\N	\N	emmanuel joseph edward	\N
237	92897a8a-d135-4a2e-9d38-93eb87ce8ee1	1	7	\N	Nazurah Syadiyah	\N	\N	t	2025-11-05 10:03:17.795203	23	1	1	\N	\N	\N	{"role": "VIP", "company": "MATRADE", "position": "EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:00:15.910249	2025-11-05 10:03:17.796077	\N	\N	nazurah syadiyah	\N
241	d6ed07b1-20ff-4ce1-ad7a-a263b27af7b8	1	7	\N	Herman Abdul Hamid	\N	\N	t	2025-11-05 10:15:10.043187	23	1	1	\N	\N	\N	{"role": "VIP", "company": "MIDF", "position": "RELATIONSHIP MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:04:57.038517	2025-11-05 10:15:10.043915	\N	\N	herman abdul hamid	\N
245	cae35812-eb06-4eb0-8d78-ad588e234a38	1	7	\N	Helmi Abdullah	\N	\N	t	2025-11-05 10:15:32.930753	23	1	1	\N	\N	\N	{"role": "VIP", "company": "DIDR", "position": "PEGAWAI EHWAL EKONOMI CUM (TIMBALAN PENGARAH)", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:11:47.381416	2025-11-05 10:15:32.931322	\N	\N	helmi abdullah	\N
248	edce13d2-0e6a-4cfd-905f-e5d5f805d40c	1	9	\N	Datuk Frederick Kugan	\N	\N	t	2025-11-05 11:18:40.112643	26	1	1	\N	\N	\N	{"role": "VVIP", "company": "SABAH FORESTRY DEPARTMENT", "position": "CHIEF CONSERVATOR FOREST", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:32:57.17241	2025-11-05 11:18:40.113138	\N	\N	datuk frederick kugan	\N
253	31b9781c-4491-48cd-af7b-6230b2952be6	1	7	\N	Hasyim Bin Zain	\N	\N	t	2025-11-05 10:15:58.707959	23	1	1	\N	\N	\N	{"role": "VIP", "company": "BANK RAKYAT", "position": "RELATIONSHIP MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:04:33.792501	2025-11-05 10:15:58.708863	\N	\N	hasyim bin zain	\N
257	58896f09-3e96-477a-af1a-3b5f630add0e	1	7	\N	James Ha	\N	\N	t	2025-11-05 10:39:53.581542	24	1	1	\N	\N	\N	{"role": "VIP", "company": "DONG SIN FOOD SDN BHD ", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:09:10.93016	2025-11-05 10:39:53.582244	\N	\N	james ha	\N
259	533c43da-595f-4a95-a633-fcabee5e6c98	1	7	\N	Dr Bamini Kpd Balakrishnan	\N	\N	t	2025-11-05 12:08:45.47828	30	1	1	\N	\N	\N	{"role": "VIP", "company": "ICMC, UMS", "position": "Deputy Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:18:56.755086	2025-11-05 12:08:45.479026	\N	\N	dr bamini kpd balakrishnan	\N
264	ccc5686a-9661-4403-921f-7f4a7f0861ac	1	7	\N	Noni Dinsim	\N	\N	t	2025-11-05 10:02:49.361436	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SAWIT KINABALU GROUP", "position": "MANAGER CORPORATE UNIT & COMMUNICATION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 14:06:56.091315	2025-11-05 10:02:49.362038	\N	\N	noni dinsim	\N
271	fea61691-d06c-4533-b897-8d240ceb2a17	1	1	\N	Ybhg. Datuk. Ar. James Wong Kein Peng	\N	\N	t	2025-11-05 08:00:56.007561	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SEDCO", "position": "GROUP GENERAL MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.085049	2025-11-12 01:42:46.725916	\N	\N	ybhg. datuk. ar. james wong kein peng	\N
273	034f6eb1-d9e8-429a-bf2f-a968bad70e2c	1	7	\N	Datuk Chok Yun Kiong	\N	0123456789	t	2025-11-05 10:21:29.549851	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "UNIVERSAL MOTOR SDN.BHD.", "position": "MANAGING DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.121981	2025-11-05 10:21:29.55053	\N	0123456789	datuk chok yun kiong	\N
277	e67a9eb0-d679-4d8b-978c-24345d88b31d	1	7	\N	Prof. Datuk Foo Ngee Kee	\N	\N	t	2025-11-05 10:04:16.506522	29	1	1	\N	\N	\N	{"role": "VIP", "company": "MAJLIS PENASIHAT EKONOMI SABAH", "position": "COUNCIL MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.162278	2025-11-05 10:04:16.507187	\N	\N	prof. datuk foo ngee kee	\N
278	4635c26a-fcec-4544-8201-bea6bfbae9e9	1	7	\N	Christopher Liew	\N	012345678	t	2025-11-05 11:50:09.723413	25	1	1	\N	\N	\N	{"role": "VIP", "company": "SRI KOMPUTER SDN BHD", "position": "COO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.169014	2025-11-05 11:50:09.724033	\N	012345678	christopher liew	\N
300	d481fa89-d447-4ec7-9361-0cf52f837e2d	1	7	\N	Ashley Lai Foong Yen	\N	\N	t	2025-11-05 10:09:00.523196	29	1	1	\N	\N	\N	{"role": "VIP", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.509305	2025-11-05 10:09:00.523767	\N	\N	ashley lai foong yen	\N
687	d3da400f-dc6e-49b1-a683-c311db36262d	1	1	\N	Darrel Khar	zionsign88@gmail.com	60102185785	t	2025-11-07 00:04:44.258896	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "CB Sparklab", "position": "Exhibitor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:02:14.287343	2025-11-07 00:04:44.25947	zionsign88@gmail.com	60102185785	darrel khar	\N
10	5789a677-d19a-4cb9-a1a2-9e16256c6400	1	1	\N	Winifred Koh Shuk Eng	\N	016-8406622	t	2025-11-12 01:43:48.649323	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TECHPRENEUR ASSOCIATION", "position": "ASSISTANT SECRETARY", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:46:24.964098	2025-11-12 01:47:17.900735	\N	0168406622	winifred koh shuk eng	\N
189	bb9a4d5d-1d75-471d-8e4f-ca2a214a5915	1	3	\N	Jordon Wong	\N	01118515933	t	2025-11-07 08:56:11.777266	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "Student", "coupon_referral": "", "business_industry": "Education", "print_exhibitor_tag": ""}	2025-11-03 08:07:23.842277	2025-11-07 08:56:11.777944	\N	01118515933	jordon wong	\N
161	cb4e7537-a22b-46f3-84a7-2593e4daeb71	1	1	\N	Reuben Kau Shau Fung	\N	0138818978	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "RKI CONSULTANCY SDN BHD", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:18:26.974083	2025-11-03 07:18:26.974083	\N	0138818978	reuben kau shau fung	\N
162	d71d7b41-af55-4fb0-925b-edfe21e16955	1	1	\N	ANNDIRRINA CHONG	\N	0172227972	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "INVEST SABAH BERHAD", "position": "DEPUTY HEAD OF INVESTMENT DEVELOPMENT DIVISION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:20:39.357687	2025-11-03 07:20:39.357687	\N	0172227972	anndirrina chong	\N
174	a0169f54-2178-4a36-b7cd-ba745b59d593	1	1	\N	MOHD NAZRON BIN RUSLY	\N	0182008682	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "EVOPOINT SDN BHD", "position": "TERRITORY MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:41:26.619893	2025-11-03 07:41:26.619893	\N	0182008682	mohd nazron bin rusly	\N
176	504671fe-134f-42d2-9572-9e0675d14dd8	1	1	\N	Tan Qiyuan	\N	0123848339	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Evopoint Sdn Bhd", "position": "Business Development Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:44:11.619995	2025-11-03 07:44:11.619995	\N	0123848339	tan qiyuan	\N
180	8a6c9076-f0ce-4481-9f8d-3147d6dfe7ae	1	1	\N	Ar. Rizal Ahmad Banjar	\N	0168338113	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Arkitek EDP Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:54:01.28828	2025-11-03 07:54:01.28828	\N	0168338113	ar. rizal ahmad banjar	\N
223	b7868aab-c52d-4dbf-b2da-7e12a4e45c9d	1	5	\N	Frederick Chang	\N	6012-813-0999	t	2025-11-05 08:45:24.538463	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Chang & Kamarudin", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:07:15.662011	2025-11-05 08:45:24.539167	\N	60128130999	frederick chang	\N
252	4960cab7-b2d1-4018-baca-d5f87b394b86	1	7	\N	Datin Hjh. Noor Ardilah Radzwan	\N	\N	t	2025-11-05 10:18:06.300782	23	1	1	\N	\N	\N	{"role": "VIP", "company": "BANK RAKYAT", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:04:01.025211	2025-11-05 10:18:06.301539	\N	\N	datin hjh. noor ardilah radzwan	\N
280	1f4429fe-5074-4da1-b0c1-b2bcba4d2ba6	1	7	\N	Dato Tony Looi Chee Hong	\N	\N	t	2025-11-05 02:50:15.862896	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "BAN LEE HIN GROUP", "position": "DIRECTOR OF ACCOUNTING CENTRE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.184807	2025-11-05 02:50:15.863577	\N	\N	dato tony looi chee hong	\N
282	15b79e72-9bd0-4237-8791-291559306257	1	7	\N	Prof. Dr. Ag. Asri Ag. Ibrahim	\N	\N	t	2025-11-05 10:04:50.449793	29	1	1	\N	\N	\N	{"role": "VIP", "company": "UMS FAKULTI KOMPUTERAN & INFORMATIK", "position": "PROFESSOR CHIEF DIGITAL OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.207068	2025-11-05 10:04:50.451106	\N	\N	prof. dr. ag. asri ag. ibrahim	\N
1	62bf6c55-f2c3-4f37-b66f-3a3f2403c5ac	1	1	\N	Ain Syaheera Binti Abd Rahman	\N	010-8408450	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Penang Development Corporation", "position": "System Analyst", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 01:18:43.027151	2025-11-06 02:23:46.244799	\N	0108408450	ain syaheera binti abd rahman	\N
2	efa88524-6c43-4081-8099-3d9cebc6850e	1	1	\N	Nurul Hidayah Binti Abu Bakar	\N	010-2010280	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Penang Development Corporation", "position": "Pegawai Teknologi Maklumat", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 01:55:53.084207	2025-11-05 13:09:51.04476	\N	0102010280	nurul hidayah binti abu bakar	\N
5	48e8b52e-96a5-416d-826e-471027deed8d	1	1	\N	Nelson Mosinoh	\N	012-8357449	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Gain Forlife Sdn Bhd", "position": "Managing Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 01:58:25.307248	2025-11-01 09:27:26.288541	\N	0128357449	nelson mosinoh	\N
11	a54f6b8a-6e0d-4311-903d-7f27757d604b	1	1	\N	Rosemary Pan Sook Fun	\N	012-8272764	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Baoan Welfare Association Kota Kinabalu Sabah", "position": "Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:46:52.1219	2025-11-06 02:23:46.31192	\N	0128272764	rosemary pan sook fun	\N
15	b6b26ccc-e9f6-48bc-b640-b253c3977ae8	1	1	\N	Arrif Sultan Bin Mohamed Farook	\N	+60122422100	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLElogy Berhad", "position": "Business Development Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:49:18.042483	2025-11-06 02:23:46.325298	\N	60122422100	arrif sultan bin mohamed farook	\N
24	269ae956-dc2e-4fab-bacf-f866e1a993d2	1	1	\N	Goh Hui Bee	\N	012-8063803	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Borneo Samudera Sdn Bhd", "position": "Senior Finance Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 04:02:21.415863	2025-11-01 09:31:28.734219	\N	0128063803	goh hui bee	\N
773	ed7f13d9-2a50-4d34-b47b-5280c2c79431	1	1	\N	Azrul Bin Ahmad	\N	\N	t	2025-11-12 01:40:16.61587	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SEDCO", "position": "DEPUTY GROUP GENERAL MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:38:36.825008	2025-11-12 01:40:16.616717	\N	\N	azrul bin ahmad	\N
155	4b606007-25b0-47cf-b59d-ee1072e51bbe	1	1	\N	Siti Tania	\N	012-8857957	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Torr Energy Sdn. Bhd.", "position": "Personal Assistant", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:09:46.666623	2025-11-03 07:09:46.666623	\N	0128857957	siti tania	\N
286	c7dae4ba-09f3-45c6-ba88-773660901dde	1	7	\N	Datuk Dr Roland Chia	\N	\N	t	2025-11-05 11:13:06.718491	29	1	1	\N	\N	\N	{"role": "VIP", "company": "", "position": "POLITICAL SECRETARY TO CHIEF MINISTER SABAH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.245651	2025-11-05 11:13:06.719063	\N	\N	datuk dr roland chia	\N
290	af768c05-fae5-4c1b-b84c-2b7f71d91a9c	1	7	\N	Radzwan Kong	\N	\N	t	2025-11-05 11:45:58.321041	30	1	1	\N	\N	\N	{"role": "VIP", "company": "AIRWORLD TRAVEL & TOURS SDN.BHD.", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.280589	2025-11-05 11:45:58.321532	\N	\N	radzwan kong	\N
1285	674dc9c3-d0a4-4bb0-a2dd-c4b0bdb7b833	1	1	\N	Agnes Lee Sau Han	agnesiew@yahoo.com	60168365152	t	2025-11-08 00:55:16.333833	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Skyline SIB Kota Kinabalu", "position": "Account Executive"}	2025-11-08 00:54:53.754479	2025-11-08 00:55:16.334448	agnesiew@yahoo.com	60168365152	agnes lee sau han	\N
172	5392e7c7-c646-4ca3-9864-b2e95fefa352	1	1	\N	David Noyd Michael	\N	0138860666	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "DIGITAL & COMMUNICATIONS MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:35:33.951946	2025-11-12 00:51:46.82407	\N	0138860666	david noyd michael	\N
2086	41b5ddc3-77e1-42d2-aa3b-b1f3754627c1	1	1	\N	Pau An	\N	\N	t	2025-11-12 01:48:01.103689	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TECHPRENEUR ASSOCIATION", "position": "AUDITOR"}	2025-11-12 01:47:53.632186	2025-11-12 01:48:01.104399	\N	\N	pau an	\N
899	fe5f4098-ec78-4be3-9c2f-f2081d8baeb2	1	7	\N	Kerk Loong Sing	\N	\N	t	2025-11-07 04:10:40.77058	30	1	1	\N	\N	\N	{"role": "VIP", "company": "VISTAGE", "position": "Chair", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:08:04.328537	2025-11-07 04:10:40.771099	\N	\N	kerk loong sing	\N
359	4b8e6141-175c-4a6f-9631-accfba970bba	1	6	\N	Thuy Thu Le (grace Le)	\N	\N	t	2025-11-06 02:01:40.694903	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "AQUAVANCE AGENCY", "position": "FOUNDER & CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.31071	2025-11-06 02:01:40.695557	\N	\N	thuy thu le (grace le)	\N
179	a6086d1b-2d1f-4585-b282-64bfab52d1ef	1	1	\N	Tony Lok	\N	0173832976	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "JinGo Media Corp", "position": "Executive director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:53:23.646083	2025-11-03 07:53:23.646083	\N	0173832976	tony lok	\N
183	1602be0b-9fdb-40ad-b124-925f3d6bdcfe	1	1	\N	Michael @ Hing Hock Siong	\N	014-6720355	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "FSI", "position": "Senior Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:58:58.666977	2025-11-03 07:58:58.666977	\N	\N	michael @ hing hock siong	\N
130	177e8bba-f2f7-4021-947e-b811176691fc	1	1	\N	Charlton Henry Gomes	\N	016-3469946	f	\N	23	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "ASSISTANT NETWORK MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:05:38.186732	2025-11-05 02:56:38.339917	\N	0163469946	charlton henry gomes	\N
775	ab3f5f25-55b1-4f5e-b65e-db1cc26c4ae8	1	1	\N	Pua Eng Seng	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "KKIP SDN BHD", "position": "SENIOR BROADBAND SPECIALIST", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:40:18.106115	2025-11-12 00:31:40.020978	\N	\N	pua eng seng	\N
165	5515a74e-2bb3-43ca-ac01-a142234fe60b	1	1	\N	Benjamin Lim	\N	0128336187	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Nasi Lapar 7Kens", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:25:36.382869	2025-11-03 07:25:36.382869	\N	0128336187	benjamin lim	\N
173	d3fe91b4-7f4d-4de4-8453-3e193884b310	1	1	\N	Calvin Leong	\N	0168399635	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SK Meriang Sdn Bhd", "position": "Sales Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:36:34.642524	2025-11-03 07:36:34.642524	\N	0168399635	calvin leong	\N
177	7c8a0c7d-75d0-4b40-90ec-0fd1ea9d64e8	1	1	\N	Edwin Mau	\N	0168352573	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Inspired Co", "position": "Owner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:45:11.812996	2025-11-03 07:45:11.812996	\N	0168352573	edwin mau	\N
185	c9670936-e11a-4c27-96b1-b2c8ba3489f7	1	3	\N	Wong Fui Nang	\N	0128270911	t	2025-11-07 08:56:36.60762	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:02:35.524344	2025-11-07 08:56:36.608124	\N	0128270911	wong fui nang	\N
2088	55e980ee-54ef-4f58-9638-93425f210fd8	1	1	\N	Alaura Julian	\N	\N	t	2025-11-12 01:49:30.552174	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "HUMANCE", "position": "SPOKESPERSON"}	2025-11-12 01:49:22.321001	2025-11-12 01:49:30.552987	\N	\N	alaura julian	\N
296	3960c808-8416-4b9d-9071-17abe09d4448	1	7	\N	Vellarie June Jeffrey Lungin	\N	\N	t	2025-11-05 10:28:52.542251	28	1	1	\N	\N	\N	{"role": "VIP", "company": "SODGC", "position": "BUSINESS ANALYST", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.407703	2025-11-05 10:28:52.542894	\N	\N	vellarie june jeffrey lungin	\N
1205	701b4631-6c60-464d-a3e9-becb174be0ab	1	1	\N	Kelvin Chin Kak Jia	Kelvinchin662kujie@gmail.com	601131580892	t	2025-11-07 12:33:29.431149	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "Shopee express sdnbhd", "position": "Driver"}	2025-11-07 12:33:29.431149	2025-11-07 12:33:44.298275	kelvinchin662kujie@gmail.com	601131580892	kelvin chin kak jia	\N
297	57b6cf1c-9e42-4cb8-8465-4fbb4e370c5f	1	1	\N	Normegawati Sapian	\N	012345678	t	2025-11-05 11:51:20.249794	25	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH TOURISM BOARD", "position": "SPECIAL OFFICER TO CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.430202	2025-11-12 00:51:55.123104	\N	012345678	normegawati sapian	\N
293	632252cf-3d0f-4f12-9777-4099afd02a71	1	1	\N	Haji Azrul Bin Haji Ahmat	\N	\N	t	2025-11-05 10:26:45.858962	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SEDCO", "position": "DEPUTY GROUP MANAGER (CORPORATE AFFAIRS & FINANCE)", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.329251	2025-11-12 01:39:46.983864	\N	\N	haji azrul bin haji ahmat	\N
299	cbd15fe7-1298-41ab-a588-752dbbad38d8	1	7	\N	Paul Ang See Yao	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.494033	2025-11-04 07:54:58.83615	\N	\N	paul ang see yao	\N
302	380da7bc-a4b4-46c7-9500-f2ab97e1a335	1	7	\N	Peggy Yap	\N	\N	t	2025-11-05 12:12:49.429604	30	1	1	\N	\N	\N	{"role": "VIP", "company": "Game Definer Co.", "position": "Business Development Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.553744	2025-11-05 12:12:49.430305	\N	\N	peggy yap	\N
357	f4dfeaca-d316-4ee6-80c4-b9acc9e9a22c	1	6	\N	Maverick Foo	\N	\N	t	2025-11-05 08:55:39.966423	29	1	1	\N	\N	\N	{"role": "Speaker", "company": "RADIANT INSTITUTE", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.282755	2025-11-06 01:35:29.94884	\N	\N	maverick foo	\N
358	8d2ea833-bb3a-44ac-8010-23ceccc51e4f	1	6	\N	Alan Low	\N	\N	t	2025-11-06 02:01:50.893073	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "VISTAGE", "position": "CHAIR / CEO COACH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.299731	2025-11-06 02:01:50.89368	\N	\N	alan low	\N
361	ee4fe899-30e2-4f67-b0bf-28dedaad61d8	1	6	\N	Assel (dupliate)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.331584	2025-11-06 02:07:05.389041	\N	\N	assel (dupliate)	\N
362	03f91a8b-cc4f-49f4-a238-c4234242eeb6	1	6	\N	Heaster Andrea Hilary	\N	\N	t	2025-11-06 02:01:18.500699	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "MESSENGERCO.AI (MALAYSIA)", "position": "CEO & CO-FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.346096	2025-11-06 02:01:18.501421	\N	\N	heaster andrea hilary	\N
363	93e895de-86e6-4c73-af15-d3f57db06908	1	6	\N	Cherise Ling	\N	\N	t	2025-11-06 02:00:36.006465	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "Tiktok Shop Malaysia", "position": "Community Manager of Strategic Partnership", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.359121	2025-11-06 02:00:36.00717	\N	\N	cherise ling	\N
365	c3f3f3a7-edd0-4d57-aea8-188a0ed333b4	1	6	\N	Jasper Tai	\N	\N	t	2025-11-06 01:59:58.786463	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "J A TECH (MALAYSIA)", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.386438	2025-11-06 01:59:58.787165	\N	\N	jasper tai	\N
696	615e644b-0679-43e8-8188-9e4a1e52c55e	1	1	\N	Lim Fui Tze	csy_lim@hotmail.com	601172686078	t	2025-11-07 00:05:24.321212	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "ADC DRIVING INSTITUTE SDN BHD", "position": "TUTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:04:45.601719	2025-11-07 00:05:24.321778	csy_lim@hotmail.com	601172686078	lim fui tze	\N
159	ec0cc575-7bcf-4112-ab36-3bf16ded7d9e	1	1	\N	JEFF YEAP	\N	0193707777	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "RESTU MART SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:17:02.804171	2025-11-03 07:17:02.804171	\N	0193707777	jeff yeap	\N
160	6ee8a151-ca29-47a8-ba03-19f8501475a9	1	1	\N	Wong Ming Cheng	\N	0128628080	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "IQI REALTY", "position": "Negotiator", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:17:41.569013	2025-11-03 07:17:41.569013	\N	0128628080	wong ming cheng	\N
169	85c56bdd-7afc-42d3-978e-22cd781a9a42	1	1	\N	Ng Vui Hiung	\N	60168310264	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Prudential Assurance Malaysia Berhad", "position": "Consultant", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:30:36.672666	2025-11-03 07:30:36.672666	\N	60168310264	ng vui hiung	\N
171	6aa0558e-e817-4085-bdc8-2e3be2194b66	1	1	\N	Siti Fatimah Binti Abdul Rahman	\N	0138603937	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "ASSISTANT MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:34:55.836247	2025-11-06 02:23:46.513726	\N	0138603937	siti fatimah binti abdul rahman	\N
1284	d3e0db16-59df-4424-b791-dbb43aec82db	1	1	\N	Stephen Wong	tukimenterprise@yahoo.com	60168369610	t	2025-11-08 00:55:24.4807	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Skyline sib", "position": "Staff"}	2025-11-08 00:54:51.024926	2025-11-08 00:55:24.481384	tukimenterprise@yahoo.com	60168369610	stephen wong	\N
182	321cf7c7-b4e8-42ba-b8d8-05a9d8c64b9a	1	1	\N	Joseph Tan Lei Fueng	\N	60162327757	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "", "position": "DEALER PRINCIPAL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:58:19.53465	2025-11-06 02:23:46.536467	\N	60162327757	joseph tan lei fueng	\N
309	6d89d5d0-69c5-48e9-b0fa-d4e660ea22db	1	7	\N	Natalie Fung	\N	0198527078	t	2025-11-05 10:37:49.696702	28	1	1	\N	\N	\N	{"role": "VIP", "company": "FSI", "position": "President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.665167	2025-11-05 10:37:49.697328	\N	0198527078	natalie fung	\N
158	4e2c93a4-561d-4427-95e4-d8fdadbc6882	1	1	\N	Anna Liew	\N	0168303994	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Mega City Builder Sdn Bhd", "position": "Sales Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:11:18.7636	2025-11-03 07:11:18.7636	\N	0168303994	anna liew	\N
211	1432d98b-0333-4e47-a7b5-c043c80d6b8f	1	5	\N	Norhezly Mohd Ghani	\N	088-264 000	t	2025-11-05 08:07:03.040465	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Qhazanah Sabah Berhad", "position": "Head of Tech", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:58:19.774866	2025-11-05 08:07:03.041042	\N	088264000	norhezly mohd ghani	\N
310	8af55fd6-8e0d-43ca-93df-8bd700a1d4df	1	7	\N	Datuk Richard Lim	\N	0198807648	t	2025-11-05 11:53:19.80796	25	1	1	\N	\N	\N	{"role": "VIP", "company": "", "position": "Intermediate Past President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.682166	2025-11-05 11:53:19.808733	\N	0198807648	datuk richard lim	\N
312	b5998ab8-f2dc-43bf-a6a1-bfd756dbe6a6	1	7	\N	Yap Li Ling	\N	0128831038	t	2025-11-05 11:54:05.631286	30	1	1	\N	\N	\N	{"role": "VIP", "company": "Sabah Employers Association", "position": "Assistant Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.721823	2025-11-05 11:54:05.631904	\N	0128831038	yap li ling	\N
317	7ee45cc0-6ca3-4974-ba31-3fe1c019b77a	1	7	\N	Ron Chong T K	\N	0128025667	t	2025-11-05 11:49:42.798744	25	1	1	\N	\N	\N	{"role": "VIP", "company": "METAVERSE SOLUTIONS", "position": "Founder", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.796638	2025-11-05 11:49:42.799406	\N	0128025667	ron chong t k	\N
321	128bef33-240a-4b7b-acca-e2cdb35d26a4	1	7	\N	Amy Wee	\N	01135591419	t	2025-11-05 11:38:28.886618	25	1	1	\N	\N	\N	{"role": "VIP", "company": "TED SOLUTIONS", "position": "Expo management", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.863484	2025-11-05 11:38:28.887318	\N	01135591419	amy wee	\N
325	a24f4247-2cb3-4528-8e55-7ac994add449	1	9	\N	Datuk William Ng	\N	\N	t	2025-11-05 11:34:51.706897	29	1	1	\N	\N	\N	{"role": "VVIP", "company": "", "position": "Samenta National President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.917043	2025-11-05 11:34:51.707414	\N	\N	datuk william ng	\N
331	eb5fb3f9-44d4-4b97-b034-9083d44c4584	1	6	\N	Datuk George Taitim Tulas	\N	\N	t	2025-11-05 09:18:39.224615	23	1	1	\N	\N	\N	{"role": "Speaker", "company": "SABAH CREDIT CORPORATION", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.993914	2025-11-05 09:18:39.225266	\N	\N	datuk george taitim tulas	\N
334	59053f14-b4a5-4522-bcc5-4ee9c76a018a	1	9	\N	Lim Chee How	\N	\N	t	2025-11-05 11:26:01.987708	29	1	1	\N	\N	\N	{"role": "VVIP", "company": "TAPWAY (MALAYSIA)", "position": "CEO & FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.035786	2025-11-05 11:26:01.989264	\N	\N	lim chee how	\N
337	96cc6819-ff4e-4a69-bbe6-8a083fb0f120	1	6	\N	Dave Hajdu	\N	\N	t	2025-11-06 02:00:12.218568	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "EDGE8.AI, BE TECH-FORWARD (USA)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.066668	2025-11-06 02:00:12.219311	\N	\N	dave hajdu	\N
374	a450dcfa-31ad-4fdb-a8ee-f92ad5047e5c	1	7	\N	Dato' Seri Winston Liaw	\N	108448888	t	2025-11-05 12:12:25.874519	25	1	1	\N	\N	\N	{"role": "VIP", "company": "Airworld Travel and Tours Sdn Bhd", "position": "Chairman", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 03:06:02.967163	2025-11-05 12:12:25.875134	\N	108448888	dato' seri winston liaw	\N
827	0238bd22-c111-4607-8939-89584e18ee45	1	1	\N	Chang Wee Kuong	antcwk@gmail.com	60163314271	t	2025-11-07 03:02:44.566528	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Farm-In PLT", "position": "Founder", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:02:26.755705	2025-11-07 03:02:44.567151	antcwk@gmail.com	60163314271	chang wee kuong	\N
1214	a3b86418-5a35-4a19-91de-77d123ac0ff7	1	3	\N	John Doe	\N	60138375588	t	2025-11-08 00:28:36.986226	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ltaiga", "position": "Ceo"}	2025-11-08 00:14:24.803232	2025-11-08 00:28:36.98728	\N	60138375588	john doe	\N
340	51740875-69a6-45e0-af72-9cc02bf9985f	1	6	\N	Christoper Ng	\N	\N	t	2025-11-06 01:59:47.977461	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "TRINITY42(MALAYSIA)", "position": "GROUP CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.091603	2025-11-06 01:59:47.978132	\N	\N	christoper ng	\N
2089	4bfac5b4-4bc1-416d-a9be-efea2ef3442a	1	1	\N	Darrell Sandah	\N	\N	t	2025-11-12 02:11:48.478	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "ORION UNIVERSAL", "position": "GENERAL MANAGER"}	2025-11-12 02:11:22.537265	2025-11-12 02:11:48.478805	\N	\N	darrell sandah	\N
779	79b039af-04fd-440b-af55-1e6a0a080c2d	1	1	\N	Byran Theutama	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "NAM HENG SAFETY GLASS (SABAH) SDN BHD", "position": "HR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:44:52.149498	2025-11-11 07:09:01.532091	\N	\N	byran theutama	\N
342	fb2ba587-d7f1-4637-97ca-063ff8044ea4	1	6	\N	Dr Sisopa Riwatthana	\N	\N	t	2025-11-06 02:06:16.423937	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "ENTREPRENEUR & BUSINESS CONSULTANT (THAILAND)", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.110968	2025-11-06 02:06:16.424722	\N	\N	dr sisopa riwatthana	\N
343	ea1f71f7-2e69-44a4-b658-82d4b8856fad	1	6	\N	Prof Dr Loh Wei Hoong	\N	\N	t	2025-11-06 02:05:38.504804	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "BUSINESS STRATEGIST & PROFESSOR (MALAYSIA)", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.119009	2025-11-06 02:05:38.505443	\N	\N	prof dr loh wei hoong	\N
346	09cf541f-955b-4a3a-b195-82f4017c1fff	1	6	\N	Assel Mussagaliyeva	\N	\N	t	2025-11-06 01:59:38.512059	25	1	1	\N	\N	\N	{"role": "Speaker", "company": "EDUTECH FUTURE (SINGAPORE)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.141069	2025-11-06 01:59:38.512678	\N	\N	assel mussagaliyeva	\N
349	96d5697b-9557-4809-9f41-9926824ff4e8	1	6	\N	Chiew Ler Chern	\N	\N	t	2025-11-05 09:32:53.309638	29	1	1	\N	\N	\N	{"role": "Speaker", "company": "DREAMTECH (MALAYSIA)", "position": "FOUNDER AND CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.177223	2025-11-05 09:32:53.310223	\N	\N	chiew ler chern	\N
352	4269dd7c-49b3-47f6-9d0a-c9a5351916c3	1	6	\N	Eugene Teow	\N	\N	t	2025-11-06 02:02:46.082682	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "CYGNUS TECHNOLOGY SOLUTION (MALAYSIA)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.219165	2025-11-06 02:02:46.083313	\N	\N	eugene teow	\N
355	8875cff4-5e14-4ead-8ce4-7ebe6325fb46	1	6	\N	Victor Bong	\N	\N	t	2025-11-05 08:58:09.651492	26	1	1	\N	\N	\N	{"role": "Speaker", "company": "VCORP", "position": "FOUNDER & CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.255899	2025-11-06 01:34:18.181728	\N	\N	victor bong	\N
364	203c027f-1615-47c8-9f46-c41b556e541c	1	6	\N	Chiew (duplicate Speaker)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.376453	2025-11-06 02:07:38.70021	\N	\N	chiew (duplicate speaker)	\N
366	7702def2-f721-4342-8b47-04a8337348e7	1	6	\N	Alvin Chong (no Need Print)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.411762	2025-11-05 07:26:32.371604	\N	\N	alvin chong (no need print)	\N
370	c2814e7d-8121-4ed2-9001-c5919f23bded	1	6	\N	Arthur Pang (duplicate Vip)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:04.469722	2025-11-06 02:06:18.098143	\N	\N	arthur pang (duplicate vip)	\N
373	185ad80f-80cc-4559-a998-80432ca94842	1	1	\N	Michellr	Sdmin@gmail.com	60193883994	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "Ums", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 08:50:07.123597	2025-11-04 08:50:07.123597	sdmin@gmail.com	60193883994	michellr	\N
378	7d754d4f-75ff-46eb-939a-9c2a89df483a	1	9	\N	Jason Lau	\N	\N	t	2025-11-05 11:31:21.454537	30	1	1	\N	\N	\N	{"role": "ORGANISING PARTNER", "company": "KIMORA ENTERTAINMENT NETWORK (K.E.N)", "position": "ADVISOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.770375	2025-11-05 11:31:21.455522	\N	\N	jason lau	\N
381	c3a2d393-a966-4cab-aea0-babbc7ec68ef	1	9	\N	Datuk Dr. Hajah Rosmawati Haji Lasuki, J.p.	\N	\N	t	2025-11-05 10:12:13.340124	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "SABAH INTERNATIONAL CONVENTION CENTRE", "position": "CHIEF EXECUTIVE OFFICER OF SABAH INTERNATIONAL CONVENTION CENTRE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.792875	2025-11-05 10:12:13.340873	\N	\N	datuk dr. hajah rosmawati haji lasuki, j.p.	\N
778	46b71fb3-75c9-476f-b195-fe4f2e9d85b5	1	1	\N	Leonard	\N	\N	t	2025-11-12 00:33:43.38031	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KK POS SYSTEM SDN BHD", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:42:23.759773	2025-11-12 00:33:43.381042	\N	\N	leonard	\N
387	a768338d-df96-41fc-a7c7-5eef3ca98eb2	1	1	\N	Andrew Pang Kian Phin	\N	60178116070	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "TWO THOUSAND AND ONE COMPUTER (M) SDN BHD", "position": "SENIOR SYSTEM & NETWORK ENGINEER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.825426	2025-11-06 02:23:45.825426	\N	60178116070	andrew pang kian phin	\N
388	1e27ced2-755a-4ebf-bd55-1d2fc7b47739	1	1	\N	Chai Tze Tse	\N	60178115331	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Hope Dental Sdn Bhd", "position": "Account & Admin Officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.845329	2025-11-06 02:23:45.845329	\N	60178115331	chai tze tse	\N
389	074e21f1-0f08-4e00-8fc5-1bea82d50ef4	1	1	\N	Francis Chan	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "SECRETARY GENERAL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.855677	2025-11-06 02:23:45.855677	\N	\N	francis chan	\N
1181	124b664d-3461-4e3a-8c7b-0d9f88b715da	1	1	\N	Mohd Badrul Hisham Bin Mazland	bartaghastpahang@gmail.com	60178984122	t	2025-11-07 09:45:50.595942	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "RISDA", "position": "Administration"}	2025-11-07 09:45:50.595942	2025-11-07 09:45:50.595942	bartaghastpahang@gmail.com	60178984122	mohd badrul hisham bin mazland	\N
946	bdbdd8bd-6719-4c6e-9000-af100362ef85	1	1	\N	Brenda Lo Chia Wen	bgriseldxx22@gmail.com	60107993874	t	2025-11-07 05:19:39.530497	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly Sabah ", "position": "Tax Junior ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:19:17.296956	2025-11-07 05:19:39.531014	bgriseldxx22@gmail.com	60107993874	brenda lo chia wen	\N
212	c6d7d390-598d-42bf-b458-ec3b9e29c7b4	1	5	\N	Jimmy Lam	\N	60 19-851 3036	t	2025-11-05 08:07:41.15959	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Pintar Investment", "position": "Co-Founder", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:58:51.587028	2025-11-05 08:07:41.160249	\N	60198513036	jimmy lam	\N
213	0b4a9e4a-6e71-47d1-914a-563a0b3bb002	1	5	\N	Dr Edward Chua	\N	012- 289 7911	t	2025-11-05 08:15:57.476541	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "ESG Borneo", "position": "Consultancy in ESG Sustainability", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:59:26.403724	2025-11-05 08:15:57.477245	\N	0122897911	dr edward chua	\N
2090	302e4ce9-2577-4aa0-b5a4-6988147ae5fc	1	1	\N	Samantha Lee	Smlee@hotmail.com	60128283537	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Daily Food", "position": "Manager"}	2025-11-12 07:53:27.397403	2025-11-12 07:53:27.397403	smlee@hotmail.com	60128283537	samantha lee	\N
391	6e36919f-e749-4c63-b3af-cdcada660de8	1	1	\N	Wilson Chia	\N	\N	t	2025-11-07 00:24:26.894342	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "COUNCIL MEMBER cum DIRECTOR OF MARKETING & COMMUNICATION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.873057	2025-11-07 00:24:26.895036	\N	\N	wilson chia	\N
218	cec47aba-ceb0-44fe-8b15-638e8315dad3	1	5	\N	Dr Sri Ganesh Michiel	\N	60127112888	t	2025-11-05 08:17:07.381086	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "MyBHA", "position": "National President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:03:22.672863	2025-11-05 08:17:07.381843	\N	60127112888	dr sri ganesh michiel	\N
224	c51b8b57-0dd5-4315-8322-758b8e92ba7d	1	5	\N	Andy Lee Chen Hiung	\N	6012-866-1687	t	2025-11-06 01:03:59.176729	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "UMS FACULTY OF BUSINESS,ECONOMICS AND ACCOUNTANCY", "position": "DIRECTOR OF ACCOUNTING CENTRE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:08:01.949209	2025-11-06 01:03:59.177928	\N	60128661687	andy lee chen hiung	\N
225	3a6f37d7-51c2-4f9f-ae57-1f05a79b6b0a	1	5	\N	Chu Wen Tyng	\N	6012-803-6970	t	2025-11-05 08:05:07.172919	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "TAR UMT", "position": "Branch Head, Principle Lecturer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:08:44.37703	2025-11-05 08:05:07.173491	\N	60128036970	chu wen tyng	\N
390	09756f9c-08dc-444a-95d6-5b959b14c782	1	1	\N	Yap Por Chik	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "COUNCIL MEMBER cum DIRECTOR  OF AGRICULTURE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.863086	2025-11-06 02:23:45.863086	\N	\N	yap por chik	\N
215	5b073dec-6741-4f3b-8da3-8a3e01b0b3ba	1	1	\N	Mrs Yap	\N	016-877 5757	t	2025-11-05 08:10:30.856195	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "CRAZY MIC", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:01:29.445045	2025-11-11 07:30:21.913159	\N	0168775757	mrs yap	\N
830	2a440d5f-2c31-4a30-9f2c-01bf7c6581f2	1	1	\N	Effa	eyippa0604@gmail.com	601126280604	t	2025-11-07 03:23:19.121141	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BTC Maju Holding Sdn Bhd ", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:03:22.332903	2025-11-07 03:23:19.121814	eyippa0604@gmail.com	601126280604	effa	\N
947	dfe87fa5-6c40-4c33-b6bd-780e65d415d4	1	1	\N	Nisa	chrisreaeve@gmail.com	60165093611	t	2025-11-07 05:19:52.093523	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Jhewa", "position": "Promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:19:29.778258	2025-11-07 05:19:52.094079	chrisreaeve@gmail.com	60165093611	nisa	\N
392	2d0a693e-5082-4f58-a085-7aeb4400fe13	1	1	\N	Jazlyn Yong	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.88164	2025-11-06 02:23:45.88164	\N	\N	jazlyn yong	\N
393	d7a6f243-635d-4f6d-9602-c82bf7eb11a4	1	1	\N	Edward Tee	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.892256	2025-11-06 02:23:45.892256	\N	\N	edward tee	\N
394	e6cb3923-5c9e-4419-9044-bc49f3cf5c37	1	1	\N	Richard Tham	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.900763	2025-11-06 02:23:45.900763	\N	\N	richard tham	\N
395	423feab0-99dc-4eee-b32e-8fc742192197	1	1	\N	Samantha Oh	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.908765	2025-11-06 02:23:45.908765	\N	\N	samantha oh	\N
396	dbac2429-6e6f-4ebb-8344-540a6404775f	1	1	\N	Vincent Yong	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.918948	2025-11-06 02:23:45.918948	\N	\N	vincent yong	\N
397	072987a8-e4cf-463e-b411-d33638893417	1	1	\N	Willie Ng	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.925623	2025-11-06 02:23:45.925623	\N	\N	willie ng	\N
398	2b762b1b-c09b-4cac-b4a7-18aeb09cd033	1	1	\N	Sopinal Chong	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Association of Sabah", "position": "MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.935977	2025-11-06 02:23:45.935977	\N	\N	sopinal chong	\N
399	cce084a1-e513-41b2-a226-98264c22c149	1	1	\N	Akmal Khairi Bin Wahap	\N	60128797947	t	2025-11-07 04:40:07.269827	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "ASSISTANT LECTURER FD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.944011	2025-11-07 04:40:07.270553	\N	60128797947	akmal khairi bin wahap	\N
401	7bb1d2da-34cb-467b-a5d2-007f85a1da3c	1	1	\N	Rudy Chin Lan Yin	\N	60168421399	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "LECTURER ID", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.955464	2025-11-06 02:23:45.955464	\N	60168421399	rudy chin lan yin	\N
402	647dc82e-2696-47a1-97fe-4aa95776c6f2	1	1	\N	Dominic Chong	\N	60128387678	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "CS PHAU & CO", "position": "Partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.960574	2025-11-06 02:23:45.960574	\N	60128387678	dominic chong	\N
1078	5377f584-bd72-4bf9-8ebd-5a329aca52cf	1	3	\N	Catherine Lim	\N	\N	t	2025-11-07 09:56:45.907569	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.133545	2025-11-07 09:56:45.908405	\N	\N	catherine lim	\N
400	d55cd7da-1a1f-4a59-880b-b08e5fb08136	1	1	\N	Nur Fatin Binti Abd Aziz	\N	60137122731	t	2025-11-07 04:31:54.438088	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "INTERIM ARCHITECTURE HOD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.949892	2025-11-07 04:31:54.438847	\N	60137122731	nur fatin binti abd aziz	\N
217	3204506c-79ac-4f98-82aa-583cd5bd617a	1	5	\N	Jet Yong	\N	016-821 7892	t	2025-11-05 08:12:35.298321	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Platinum Dental Group", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:02:48.518901	2025-11-05 08:12:35.299243	\N	0168217892	jet yong	\N
219	d9ac6386-153c-4e32-bd49-920b786b3b2b	1	5	\N	Jeff Lu	\N	6010-931-1600	t	2025-11-05 07:58:27.139953	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Minyak V.W. Enterprise Sdn Bhd", "position": "Director of Sales & Marketing", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:04:04.34249	2025-11-05 07:58:27.140681	\N	60109311600	jeff lu	\N
220	6c7b5255-4eff-42e2-8294-2b500ed434a0	1	5	\N	Brandon Chin	\N	6012-802-9339	t	2025-11-05 08:16:47.39979	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Borneo Referral Group Sdn Bhd", "position": "Founder & CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:04:41.164978	2025-11-05 08:16:47.400483	\N	60128029339	brandon chin	\N
221	c900919d-df7d-4269-9f0f-b6dec3477c09	1	5	\N	Richard Chong	\N	6016-838-0022	t	2025-11-05 09:11:02.119688	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "KK Land Properties", "position": "Probationary Estate Agent", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:05:26.457528	2025-11-05 08:17:33.018494	\N	60168380022	richard chong	\N
222	ffa25a10-2e12-49c9-b9cc-2855a7b2d03c	1	5	\N	Jaccie Koh	\N	6016-464-6392	t	2025-11-05 08:24:07.946689	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Invest Sabah", "position": "Head of Marketing and Corporate Communications", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:06:16.782895	2025-11-05 08:24:07.947472	\N	60164646392	jaccie koh	\N
404	46845f64-3573-444c-83d3-1f191293bf96	1	1	\N	Joey Yong	\N	60168467607	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PERCETAKAN CCS SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.97187	2025-11-06 02:23:45.97187	\N	60168467607	joey yong	\N
2091	b33a8c89-3273-42f5-8099-be13cda6c683	1	1	\N	Samantha Lee	Sam@cosm.com	60128283537	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Harvest Engineering", "position": "Manager"}	2025-11-12 08:47:11.545192	2025-11-12 08:47:11.545192	sam@cosm.com	60128283537	samantha lee	\N
782	4264d849-7c0b-425b-9efa-f8dd4e1a7d94	1	1	\N	Ms Kendy	kendyjg@gmail.com	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SATTA MEMBER- Mindah Travel Kk", "position": "TOUR MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 01:52:22.346237	2025-11-07 01:52:22.346237	kendyjg@gmail.com	\N	ms kendy	\N
405	fbae529f-d866-48e5-892c-cd0b16659570	1	1	\N	Ni Chen Chuen	\N	60163663815	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BAKERTILLY LSC TAX SERVICES SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.976997	2025-11-06 02:23:45.976997	\N	60163663815	ni chen chuen	\N
413	cb4d819c-071f-4dd9-ada2-f2e199ab0fbe	1	1	\N	Esther Cheah	\N	60123737296	t	2025-11-07 04:27:33.800697	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly Malaysia", "position": "Partner, Quality Assurance & Technical", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.036	2025-11-07 04:27:33.801418	\N	60123737296	esther cheah	\N
407	515bc6cc-cb95-4728-b3ea-cb4127f4f793	1	1	\N	Grace Lee Jun Yee	\N	60168108782	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BAKERTILLY LSC PLT", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.989768	2025-11-06 02:23:45.989768	\N	60168108782	grace lee jun yee	\N
409	27e04973-b9f0-43ad-aaf6-68e854a68a8a	1	1	\N	Vanessa Lew Tze Zhi	\N	60147186992	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SCALEUP BUSINESS CONSULTANT SDN BHD", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.010418	2025-11-06 02:23:46.010418	\N	60147186992	vanessa lew tze zhi	\N
410	a9d6b33f-a919-4c3e-ac23-6f9cfb545092	1	1	\N	Aaron Chok Lip Kwong	\N	60165879446	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BAKERTILLY LSC PLT", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.016225	2025-11-06 02:23:46.016225	\N	60165879446	aaron chok lip kwong	\N
411	26685a27-0581-44f0-8665-dc0036fe5522	1	1	\N	Alysha Phua Ke Xin	\N	60168903015	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SCALEUP CORPORATE SERVICES SDN BHD", "position": "ASSISTANT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.021673	2025-11-06 02:23:46.021673	\N	60168903015	alysha phua ke xin	\N
412	76b2a5f8-7375-418e-b423-658a5d59e77e	1	1	\N	Ho Fui Cher	\N	60149671470	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BAKERTILLY LSC TAX SERVICES SDN BHD", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.026921	2025-11-06 02:23:46.026921	\N	60149671470	ho fui cher	\N
414	0e10e93e-0031-4b5f-9656-8c5af4965326	1	1	\N	Irene Bui	\N	60128031198	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "KK Chocolate House Sdn Bhd", "position": "HR / Administrator", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.041743	2025-11-06 02:23:46.041743	\N	60128031198	irene bui	\N
415	681dca42-201b-48ee-b32a-3807f5997818	1	1	\N	Eliora Latri	\N	60135518260	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Phi Software Sdn. Bhd.", "position": "Software Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.047924	2025-11-06 02:23:46.047924	\N	60135518260	eliora latri	\N
416	3b1a617f-9c05-46e7-894c-0f21a7709126	1	1	\N	Kevin Khor	\N	60178208460	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LV Partners", "position": "Legal Advisor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.053091	2025-11-06 02:23:46.053091	\N	60178208460	kevin khor	\N
417	a34846ff-4dcb-4dae-baff-9d8665f11520	1	1	\N	Lizawati@rosclaritha Maidom	\N	60143555463	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Phi Software Sdn. Bhd.", "position": "Software Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.058536	2025-11-06 02:23:46.058536	\N	60143555463	lizawati@rosclaritha maidom	\N
838	1cb9de49-36d9-43d4-801c-140a7b6b71ca	1	1	\N	Emeyerma Binti Tanggauh	eme0210@gmail.com	60146739414	t	2025-11-07 03:10:38.301492	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "JPPM SABAH", "position": "EXCECUTIVE OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:07:57.719703	2025-11-07 03:10:38.302061	eme0210@gmail.com	60146739414	emeyerma binti tanggauh	\N
406	dc1ae4fa-b3cb-403d-8b61-6e57dfe550c1	1	1	\N	Lim Huiyin	\N	60109318035	t	2025-11-07 04:27:12.441059	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "BAKERTILLY LSC PLT", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:45.982913	2025-11-07 04:27:12.441592	\N	60109318035	lim huiyin	\N
1215	097975b2-3650-4f5d-9cf8-e9a9074de858	1	1	\N	Farid Hii Teck Hung	faridhii@hotmail.com	60198121211	t	2025-11-08 00:18:16.583382	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "MDW", "position": "Delegate "}	2025-11-08 00:17:55.629423	2025-11-08 00:18:16.583927	faridhii@hotmail.com	60198121211	farid hii teck hung	\N
426	030192f6-d545-4bf5-ac8e-2201bb166ea1	1	1	\N	Klein How	\N	6738276336	t	2025-11-07 00:20:38.768438	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jackhan Furniture Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.116268	2025-11-07 00:20:38.769026	\N	6738276336	klein how	\N
1079	c19dc560-4a68-47e4-8752-3114f09674ac	1	3	\N	David Tan	\N	\N	t	2025-11-08 01:27:12.076016	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.140306	2025-11-08 01:27:12.076659	\N	\N	jeremy ku	\N
419	efc68ab8-2c53-44e4-843f-b7646f154282	1	1	\N	Nurul Azieyati Asyiqin Binti Abdul Malek	\N	601133176074	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Phi Software Sdn. Bhd.", "position": "Software Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.069622	2025-11-06 02:23:46.069622	\N	601133176074	nurul azieyati asyiqin binti abdul malek	\N
420	6c31f19b-d24e-4ab6-a20e-83d78f634847	1	1	\N	Amy Marcus	\N	60168451526	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Universal Motor", "position": "Marketing Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.07444	2025-11-06 02:23:46.07444	\N	60168451526	amy marcus	\N
421	cc4fac26-9d22-4067-9724-e80a35733752	1	1	\N	An Nur	\N	60178177375	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Maxis Broadband Sdn Bhd", "position": "Marketing Execution & Planning EM", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.078661	2025-11-06 02:23:46.078661	\N	60178177375	an nur	\N
422	29bad3a1-2775-4416-abca-e5a6c2fc6560	1	1	\N	Jessie Lee Kah Yan	\N	60137280138	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Publishing House", "position": "Marketing and Events Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.082643	2025-11-06 02:23:46.082643	\N	60137280138	jessie lee kah yan	\N
423	38d5fa31-ef16-4ee5-98bb-9e5fa3a99c8c	1	1	\N	Ernawaty	\N	60168322420	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "POIC SABAH SDN BHD", "position": "Assistant manager, research and information", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.087322	2025-11-06 02:23:46.087322	\N	60168322420	ernawaty	\N
424	9afd3723-c22a-4060-946c-777544e53a8e	1	1	\N	Nur'fazlina Binti Azzemee	\N	60168335209	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "AMAZING BORNEO TOURS & EVENTS SDN BHD", "position": "SUPERVISOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.095583	2025-11-06 02:23:46.095583	\N	60168335209	nur'fazlina binti azzemee	\N
425	85373c8a-fdec-4b27-9e34-1495e0ef18b0	1	1	\N	Bilson Kurus	\N	60195363280	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "POIC SABAH SDN BHD", "position": "Group Senior Research & Information Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.103633	2025-11-06 02:23:46.103633	\N	60195363280	bilson kurus	\N
2092	2a82f20b-0a9f-4c8a-a0c7-b59fd8ead832	1	1	\N	Mohd. Husni Bin Yaakob	Dan@dm.cm	60128283537	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "EP Tours & Travels", "position": "Account Executive"}	2025-11-12 10:11:23.028336	2025-11-12 10:11:23.028336	dan@dm.cm	60128283537	mohd. husni bin yaakob	\N
427	5ad060f9-ff65-4e05-b32a-f68cbc055653	1	1	\N	Aaron Fernando Sualim	\N	60138674400	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "POIC SABAH", "position": "Head Environmental Sustainability Section", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.124747	2025-11-06 02:23:46.124747	\N	60138674400	aaron fernando sualim	\N
428	892fda0d-e720-4af9-8ea3-33b75ddb27d1	1	1	\N	Michael Lim	\N	60178312229	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "MLTH SOLUTION 1", "position": "N/A", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.130339	2025-11-06 02:23:46.130339	\N	60178312229	michael lim	\N
429	88b03e4f-07b3-421d-bd6e-4f61eb3a6969	1	1	\N	Harrold Tan Kuan Min	\N	60168336767	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Pets Inc", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.136458	2025-11-06 02:23:46.136458	\N	60168336767	harrold tan kuan min	\N
430	17974bab-39f1-4e16-842b-e2cf0d91f6e0	1	1	\N	Rozalia Yanna Binti Rosman	\N	601161566206	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Rezeki Masuk Resources", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.142008	2025-11-06 02:23:46.142008	\N	601161566206	rozalia yanna binti rosman	\N
431	eb3b0999-cc49-4fbe-9626-b24762f2e78c	1	1	\N	Patrick Wong Ta Ho	\N	60198219965	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Glimex Industries Sdn. Bhd.", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.146994	2025-11-06 02:23:46.146994	\N	60198219965	patrick wong ta ho	\N
432	4fa5cf62-decd-45dd-b262-fd089b4fb059	1	1	\N	Mohd Nazrin Shah Bin Nasip	\N	60149575022	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.152257	2025-11-06 02:23:46.152257	\N	60149575022	mohd nazrin shah bin nasip	\N
433	45d32dec-c02c-4aca-a8d9-9eea432d19ee	1	1	\N	Laila Binti Tahir	\N	60127861803	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga kebudayaan negeri sabah", "position": "Pegawai kebudayaan", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.158234	2025-11-06 02:23:46.158234	\N	60127861803	laila binti tahir	\N
434	fb3d698e-a922-4b8f-96d8-d33bf7223e5d	1	1	\N	Wendy Ignatius	\N	60168068818	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Office Secretary/Head Of Asset Management Unit", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.163125	2025-11-06 02:23:46.163125	\N	60168068818	wendy ignatius	\N
435	727d6bbd-f7b3-4bac-aeb8-a39afe8228ee	1	1	\N	Tracelynn Peter Jupili	\N	60138373177	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.167494	2025-11-06 02:23:46.167494	\N	60138373177	tracelynn peter jupili	\N
436	76f1cb45-841b-432c-9602-debdb0c518f3	1	1	\N	Said Ali Bin Said Idrus	\N	60168247346	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "Pegawai Kebudayaan", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.172829	2025-11-06 02:23:46.172829	\N	60168247346	said ali bin said idrus	\N
437	83f37ffb-8e09-44cb-81d3-327bb6f81c5b	1	1	\N	Hamidun Bin Jaharun	\N	601160527326	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "Pen Pegawai Tadbir", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.177228	2025-11-06 02:23:46.177228	\N	601160527326	hamidun bin jaharun	\N
790	991a6aa5-83c2-4ffd-a439-0e41d2dc6c1c	1	1	\N	Christie Mahadin	chrst1205@gmail.com	60182221243	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Great Eastern", "position": "Business Development Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:33.024333	2025-11-07 02:26:33.024333	chrst1205@gmail.com	60182221243	christie mahadin	\N
1080	90c9ffde-459d-458f-ae1c-1941981dfbb5	1	3	\N	Lim Yit Tshu	\N	\N	t	2025-11-07 10:53:54.769167	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.146827	2025-11-07 10:53:54.769871	\N	\N	lim yit tshu	\N
438	3cdcbefd-3a8b-47e4-b133-015844e8fcb6	1	1	\N	Jason Blasius	\N	60138501579	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH CULTURAL BOARD", "position": "HUMAN RESOURCE MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.181852	2025-11-06 02:23:46.181852	\N	60138501579	jason blasius	\N
2093	0f8b6745-d64b-4c7f-87a8-6e7e3cca8e62	1	1	\N	Natasha	Nat@asm.com	60128283537	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Global Production", "position": "Supervisor"}	2025-11-13 00:35:13.188975	2025-11-13 00:35:13.188975	nat@asm.com	60128283537	natasha	\N
454	9a7226f0-9fe4-4b79-a037-08a08a642dee	1	1	\N	Mr. Ho Fung Shan	\N	60198829933	t	2025-11-12 02:08:51.218959	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORNION TIMBER", "position": "SECRETARY GENERAL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.299784	2025-11-12 02:08:51.21974	\N	60198829933	mr. ho fung shan	\N
444	5c855f3b-5526-4a7a-894c-2345f023b916	1	1	\N	Cleo Lajawai	\N	60167706211	t	2025-11-07 00:34:02.002263	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "FSI", "position": "COUNCIL MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.208979	2025-11-07 00:34:02.003046	\N	60167706211	cleo lajawai	\N
19	0ff80aa7-c01c-4339-8112-1a1b3a1d9879	1	1	\N	Raja Nur Hidayah Binti Raja Badrul Hazim	\N	013-2001884	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLELOGY BERHAD", "position": "Project Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:50:51.554201	2025-11-06 02:23:46.351037	\N	0132001884	raja nur hidayah binti raja badrul hazim	\N
263	e02184e0-036e-4e61-a987-f4312e013f34	1	7	\N	Liaw Hen Kong	\N	\N	t	2025-11-05 10:22:14.826096	23	1	1	\N	\N	\N	{"role": "VIP", "company": "FMM SABAH", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 14:00:06.698125	2025-11-05 10:22:14.826656	\N	\N	liaw hen kong	\N
439	cf5ef77e-b695-4978-9d14-d54768138e38	1	1	\N	Zarinah Amiludin	\N	60138653977	t	2025-11-12 00:44:27.08192	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.186092	2025-11-12 00:44:27.082752	\N	60138653977	zarinah amiludin	\N
440	013ce009-95bf-45ba-8d29-aae9fa8e1baa	1	1	\N	Ivy Chang Qi Jun	\N	601125241362	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "SATFF", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.190431	2025-11-06 02:23:46.190431	\N	601125241362	ivy chang qi jun	\N
441	d7492f8d-18af-4c23-a219-2616ad84e402	1	1	\N	Rohana Teo Yen Ni	\N	60178337313	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Cultural Board", "position": "Administrative Assistant", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.195743	2025-11-06 02:23:46.195743	\N	60178337313	rohana teo yen ni	\N
442	4d457b5e-c3c6-4187-a4c8-8833c49d4806	1	1	\N	Al-amin Bin Monib	\N	60102582108	t	2025-11-11 07:55:48.506014	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "RAYYIZQI COMPANY", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.200253	2025-11-11 07:55:48.506887	\N	60102582108	al-amin bin monib	\N
443	68a9c9d1-24f5-4299-b4be-aa2cfcecca50	1	1	\N	Jes Lim	\N	601131794848	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "FSI", "position": "ADVISOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.204874	2025-11-06 02:23:46.204874	\N	601131794848	jes lim	\N
795	5536d9a0-df8a-4ce3-86d4-d198269f02b2	1	1	\N	Laura Miatong	laura.miatong@investsabah.gov.my	60138832378	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Invest Sabah Bhd ", "position": "Senior Exec", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:32:22.652689	2025-11-07 02:32:22.652689	laura.miatong@investsabah.gov.my	60138832378	laura miatong	\N
445	de0f1bee-8aab-41cb-adf8-3489e2a0de1e	1	1	\N	Jerome Tew Jun Xiong	\N	60174860902	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Unique dental", "position": "Principal dentist", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.213525	2025-11-06 02:23:46.213525	\N	60174860902	jerome tew jun xiong	\N
446	cc71a967-761b-4ac7-ad45-e55338ed1320	1	1	\N	Jack Liew	\N	60109195121	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Universal Motor", "position": "Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.21787	2025-11-06 02:23:46.21787	\N	60109195121	jack liew	\N
447	4d066a88-1422-41c4-883a-f82fa0268856	1	1	\N	Alvin Quek Totu	\N	60138187730	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Universal Eden Holidays Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.222743	2025-11-06 02:23:46.222743	\N	60138187730	alvin quek totu	\N
448	933b8476-33a8-4ccd-9c88-e58cf1215e79	1	1	\N	Joyce Tay	\N	60109545562	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Universal motor", "position": "Marketing executives", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.227611	2025-11-06 02:23:46.227611	\N	60109545562	joyce tay	\N
449	b0b96ded-af93-4a07-a263-e04595e72463	1	1	\N	Radwina Binti Ibrahim	\N	60168328944	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "UNIVERSAL MOTOR SDN BHD", "position": "DIGITAL MARKETING DIVISION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.23257	2025-11-06 02:23:46.23257	\N	60168328944	radwina binti ibrahim	\N
450	ee61c631-9fcf-4089-af47-45156d4648c8	1	1	\N	Calvin Liew Chee Hong	\N	60122216540	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Canon Marketing (Malaysia) Sdn Bhd", "position": "Senior Manager - Head of Branch", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.23752	2025-11-06 02:23:46.23752	\N	60122216540	calvin liew chee hong	\N
451	62170f46-6b66-4885-afa8-fe72fba498c4	1	1	\N	Edwin Ng (vvip)	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.273371	2025-11-06 02:23:46.273371	\N	\N	edwin ng (vvip)	\N
452	f4a18186-0ab8-478e-9a73-12f8e48c4a9f	1	1	\N	Mr. Lee Lye Soon	\N	60198604899	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Excella Wood Industries Sdn Bhd", "position": "Committee Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.288249	2025-11-06 02:23:46.288249	\N	60198604899	mr. lee lye soon	\N
453	1dde45dc-8b5e-49ee-aa68-1946a86dc03a	1	1	\N	Mr. Sia Mee Kuong	\N	60168320036	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Uni Lumber Sdn Bhd", "position": "Committee Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.293976	2025-11-06 02:23:46.293976	\N	60168320036	mr. sia mee kuong	\N
455	e5ed80e7-afc4-4623-a03f-399bb7b576fe	1	1	\N	Hiew Ejinn	\N	60146566391	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "SOFTWARE DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.332216	2025-11-06 02:23:46.332216	\N	60146566391	hiew ejinn	\N
948	8587ec6c-4b5e-4130-ad6e-4c8898841b6b	1	1	\N	Dahyana Binti Edip	dahyanaedip2309@gmail.com	60176329106	t	2025-11-07 05:21:59.239023	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Rimbunan warisan", "position": "Markting", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:21:40.009529	2025-11-07 05:21:59.239736	dahyanaedip2309@gmail.com	60176329106	dahyana binti edip	\N
1081	33cc8d98-cdb3-4d03-ba1a-c7a9a1a16f22	1	3	\N	Gavril Lo	\N	\N	t	2025-11-07 10:51:01.726223	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.153706	2025-11-07 10:51:01.726978	\N	\N	gavril lo	\N
14	57390568-d57f-4e43-9fe2-d95fe7852276	1	1	\N	Benjamin Tan	\N	012-3400055	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLElogy Berhad", "position": "General Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:48:57.380722	2025-11-01 09:49:23.918953	\N	0123400055	benjamin tan	\N
26	33090ae9-bcee-4f60-8d6f-ec623559f2f3	1	1	\N	Jason Tai Bing Ren	\N	60178028088	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "UNIANG PLASTIC INDUSTRIES SDN BHD", "position": "SALES MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 04:05:38.924103	2025-11-06 02:23:46.42586	\N	60178028088	jason tai bing ren	\N
787	b978bc4c-1bfb-406a-8854-5a1c17265da4	1	1	\N	Johan Amilin	Coach.amilin@gmail.com	60138654133	t	2025-11-07 02:26:09.528631	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Rema Synergy PLT", "position": "Principle Coach", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:09.528631	2025-11-07 02:26:09.528631	coach.amilin@gmail.com	60138654133	johan amilin	\N
2094	a519a2d7-e811-409a-b666-07b2667eb52f	1	1	\N	John Doe	A@a.com	60148516962	f	\N	\N	0	1	\N	\N	\N	{"role": "Speaker", "company": "Danan", "position": "Lama"}	2025-11-13 02:38:34.803559	2025-11-13 02:38:34.803559	a@a.com	60148516962	john doe	\N
461	0a035b0a-9833-4572-b42e-def47a48952e	1	1	\N	Ag Mohd Saiful Syazwan Bin Ag Yusof	\N	60168433695	t	2025-11-12 01:17:11.004028	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BAYU ALISAH DESSERT", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.572613	2025-11-12 01:17:11.004866	\N	60168433695	ag mohd saiful syazwan bin ag yusof	\N
456	47da6a27-de01-4f81-a830-b99f731d5e2e	1	1	\N	Simon Bin Sarong	\N	60168148477	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lenbaga Kebudayaan Negeri Sabah", "position": "Kerani", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.547594	2025-11-06 02:23:46.547594	\N	60168148477	simon bin sarong	\N
457	2c5fa9b7-df13-4905-9895-a855cbb79d66	1	1	\N	Ong Shao Wei	\N	601110752883	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Dreamztech (M) Berhad", "position": "Digital Marketer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.552841	2025-11-06 02:23:46.552841	\N	601110752883	ong shao wei	\N
458	6a61d129-8e64-43a4-8821-60998c9fe2ed	1	1	\N	Sharifah Hafizah Binti Sharif Endra	\N	60178013329	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Cahaya Metro Sdn Bhd", "position": "Admin Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.557766	2025-11-06 02:23:46.557766	\N	60178013329	sharifah hafizah binti sharif endra	\N
459	f656ab96-9c1b-485d-98fb-5dc3d6a3c3d7	1	1	\N	Juana Binti Kail	\N	60136103668	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Syiqin Bakery", "position": "Pengurus", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.562798	2025-11-06 02:23:46.562798	\N	60136103668	juana binti kail	\N
463	300fdc3b-2a8a-4752-b81f-f0c426ce0cb4	1	1	\N	Rosyati Binti Haji Suni	\N	60142039895	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "ZABARDAS ENTERPRISE", "position": "PENGURUS", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.582797	2025-11-06 02:23:46.582797	\N	60142039895	rosyati binti haji suni	\N
13	55c880b5-2af1-4a59-bc9c-f807ac5901a7	1	1	\N	Normegawati Sapian	\N	0128330338	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "SPECIAL OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:48:22.315599	2025-11-12 00:51:23.437806	\N	0128330338	normegawati sapian	\N
466	6f3e01da-bbb1-47ef-a484-48bd4b607b5d	1	1	\N	Rinah Linggom	\N	60198400178	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Kementerian Pelancongan Kebudayaan dan Alam Sekitar Sabah", "position": "Cultural Office", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.602011	2025-11-06 02:23:46.602011	\N	60198400178	rinah linggom	\N
467	6eca271d-edc4-47ff-bd1a-d1c3c244a9ae	1	1	\N	Sara Elisya Ahmad Shah	\N	60128202309	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Balai Seni Lukis Sabah", "position": "Pengarah", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.607892	2025-11-06 02:23:46.607892	\N	60128202309	sara elisya ahmad shah	\N
468	46b6ea6b-68d3-4aa2-be26-7d505ca2207d	1	1	\N	Rachel Stanis Buandih	\N	60198697232	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Researcher", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.613109	2025-11-06 02:23:46.613109	\N	60198697232	rachel stanis buandih	\N
469	481f356f-1449-46d3-ad4a-1acd241708bd	1	1	\N	Connie Ramy	\N	60178383384	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "PEMBANTU TADBIR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.618821	2025-11-06 02:23:46.618821	\N	60178383384	connie ramy	\N
470	2cd4b0cf-e131-4ccb-a902-b144e8099d6c	1	1	\N	Nency Edward	\N	60189627824	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "KEMENTERIAN PELANCONGAN, KEBUDAYAAN DAN ALAM SEKITAR", "position": "KERANI", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.625615	2025-11-06 02:23:46.625615	\N	60189627824	nency edward	\N
471	bf18317d-2c41-4d1e-b8b2-cc055bb49890	1	1	\N	Aieron Lonsiong Ronnie	\N	60138798849	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "Penolong pegawai teknologi maklumat", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.630692	2025-11-06 02:23:46.630692	\N	60138798849	aieron lonsiong ronnie	\N
462	9ce6b938-3475-4009-92d8-450a90ed67c3	1	1	\N	Rafidah Binti Dzulkiflee	babupop7871@gmail.com	60145937871	t	2025-11-06 23:43:23.379735	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "DFarah Enterprise", "position": "Pengurus", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.577118	2025-11-06 23:43:23.380376	babupop7871@gmail.com	60145937871	rafidah binti dzulkiflee	\N
464	a8ef2266-7917-47ae-8f6a-57be1b16452f	1	1	\N	Norkiah Binti Maasaab @maasaat	\N	60128204833	t	2025-11-07 00:11:06.324979	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KIA TRADING", "position": "OWNER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.590801	2025-11-07 00:11:06.325815	\N	60128204833	norkiah binti maasaab @maasaat	\N
788	4c65f798-29d7-4e7d-ba81-e33d27813cd1	1	1	\N	Andika Azra Bin Karim	annddikaa@gmail.com	60142352088	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Great Eastern", "position": "STAFF HQ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:18.380848	2025-11-07 02:26:18.380848	annddikaa@gmail.com	60142352088	andika azra bin karim	\N
1085	3fe49ecd-2398-40b3-bd3f-b5f0e5cb64be	1	3	\N	Stella Tay	\N	\N	t	2025-11-07 10:49:14.488657	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.183633	2025-11-07 10:49:14.489222	\N	\N	stella tay	\N
1084	7c8b86af-d200-419b-958d-a39028fbf007	1	3	\N	Daphiason Tan	\N	\N	t	2025-11-07 10:50:13.108797	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.174808	2025-11-07 10:50:13.109589	\N	\N	daphiason tan	\N
491	532c3b8e-ffd9-4662-9d3e-75396b4a747c	1	1	\N	Sr Raja Sundra Lingam@sunny Kelvin	\N	60198505747	t	2025-11-11 07:06:29.803233	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SMITHS GORE SABAH", "position": "MANAGING PROPRIETOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.782295	2025-11-11 07:06:29.804113	\N	60198505747	sr raja sundra lingam@sunny kelvin	\N
1266	816ab917-04f5-4080-8e59-69139c17d6e9	1	3	\N	Liow Se Vui	\N	60168336036	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Unemployment ", "position": "Nil"}	2025-11-08 00:46:44.934036	2025-11-08 00:46:44.934036	\N	60168336036	liow se vui	\N
473	5ebd7cd7-6d2f-4983-9083-60c587350596	1	1	\N	Maymall Frayneey	\N	60194134674	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan N.Sabah", "position": "Bhg Latihan dan Kemahiran", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.640925	2025-11-06 02:23:46.640925	\N	60194134674	maymall frayneey	\N
474	cba3b340-a330-4a1d-aa58-3ddeac852c89	1	1	\N	Jason Teo	\N	60198504338	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Golden Elate Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.647211	2025-11-06 02:23:46.647211	\N	60198504338	jason teo	\N
476	1870f8fa-0d19-48fa-aa92-65550c8ed576	1	1	\N	Dave Ang	\N	60126775105	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Easy Solar Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.66184	2025-11-06 02:23:46.66184	\N	60126775105	dave ang	\N
477	6e6053cd-726c-4c22-96db-e92caa57f629	1	1	\N	Ellen Chong	\N	60166869822	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Easy Solar Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.669228	2025-11-06 02:23:46.669228	\N	60166869822	ellen chong	\N
478	2bbb5a07-6ab7-4b15-81c1-15b4c141968d	1	1	\N	Muhammad Zureyiezan Bin Zuraimi	\N	601116302679	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Wan-Million Enterprise", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.676164	2025-11-06 02:23:46.676164	\N	601116302679	muhammad zureyiezan bin zuraimi	\N
479	87215871-c976-4b6b-a426-7c8e09a7b10a	1	1	\N	Alice Kong	\N	60146518580	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SUNFATT SDN BHD", "position": "ADMIN EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.681895	2025-11-06 02:23:46.681895	\N	60146518580	alice kong	\N
480	4be6df59-6e21-4c37-83c4-76c2e03baf92	1	1	\N	Gabriel Jee Jing	\N	60146829419	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Jee Enterprise (KK) SDN BHD", "position": "Sales manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.689904	2025-11-06 02:23:46.689904	\N	60146829419	gabriel jee jing	\N
481	05f83c76-343c-4865-bce2-a9f7f0071b28	1	1	\N	Bryon Chester	\N	60146701300	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "GD HOD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.69632	2025-11-06 02:23:46.69632	\N	60146701300	bryon chester	\N
484	5af00161-c803-41c0-894e-ab957282bac0	1	1	\N	Wong Chun Yung	\N	60102664773	t	2025-11-07 04:21:03.024078	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "International Postgraduate Coordinator", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.719116	2025-11-07 04:21:03.024842	\N	60102664773	wong chun yung	\N
483	38610691-ec89-4e0b-9bfc-d425ff1230db	1	1	\N	Nur Amirah Binti Jazuli Wilaksono	\N	60168305696	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "Interim ID HOD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.711707	2025-11-06 02:23:46.711707	\N	60168305696	nur amirah binti jazuli wilaksono	\N
832	2073b6e9-071d-4553-b199-5613708a9cdc	1	1	\N	Allen Clement Florance	allen_adek@yahoo.com	60168350451	t	2025-11-07 03:04:38.731329	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ipsos", "position": "Interviewer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:04:15.839557	2025-11-07 03:04:38.73191	allen_adek@yahoo.com	60168350451	allen clement florance	\N
485	980a8afb-fdd7-4245-874b-85fbc01c59be	1	1	\N	Alfye Alvera Narajim	\N	60146523919	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "Interim FD HOD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.724762	2025-11-06 02:23:46.724762	\N	60146523919	alfye alvera narajim	\N
486	005084fb-6728-45f9-9a95-3d4a73974e37	1	1	\N	Lee Pei Ceng	\N	60163389937	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Easy Solar Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.732312	2025-11-06 02:23:46.732312	\N	60163389937	lee pei ceng	\N
487	8ea4180d-ee4d-41dc-b3e1-bc0ca44a7efe	1	1	\N	Mackey Apison	\N	60168249277	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "GENERAL MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.737204	2025-11-06 02:23:46.737204	\N	60168249277	mackey apison	\N
488	5dc8ab30-aebf-4bfc-94c1-99c1fcee989e	1	1	\N	Bonny Lin Vun Seng	\N	601133222327	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH CONVENTION BUREAU", "position": "MARKETING COMMUNICATIONS EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.743167	2025-11-06 02:23:46.743167	\N	601133222327	bonny lin vun seng	\N
489	a068f019-c8c2-417e-9f3d-52bdc536431f	1	1	\N	Rozharina Binti Rothman	\N	60168249277	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "SECRETARY", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.767725	2025-11-06 02:23:46.767725	\N	60168249277	rozharina binti rothman	\N
490	e0af8d51-51e8-446f-9049-77cfd8cae260	1	1	\N	Nurazrina Binti Azah	\N	60143548878	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "kementerian pembangunan perindustrian dan keusahawanan", "position": "Penolong Pegawai Tadbir", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.774811	2025-11-06 02:23:46.774811	\N	60143548878	nurazrina binti azah	\N
492	818d99c2-d16b-4a57-b3c8-3b785433a922	1	1	\N	Tay Chuen Jing	\N	60109572800	t	2025-11-12 00:43:07.575724	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORENOS SDN BHD", "position": "FINANCE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.788727	2025-11-12 00:43:07.576441	\N	60109572800	tay chuen jing	\N
475	9e59d785-cba3-4833-aa6f-b3bcc57fff26	1	1	\N	Desmond Wong	\N	60168804404	t	2025-11-07 02:52:34.84222	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Amtc system sdn bhd", "position": "Chief Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.652783	2025-11-07 02:52:34.842795	\N	60168804404	desmond wong	\N
482	b1c80664-dfc0-429f-9f0c-c854578cc7ba	1	1	\N	Iman Jul Fikri	\N	60142810266	t	2025-11-07 04:20:25.601328	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "AD Lecturer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.702177	2025-11-07 04:20:25.602055	\N	60142810266	iman jul fikri	\N
512	d30ef737-9b84-49fa-a6ea-552addded66d	1	1	\N	Leong Chan Fatt	\N	60138869387	t	2025-11-07 00:26:19.503414	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "L & A Vegie Delight", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.893452	2025-11-07 00:26:19.503947	\N	60138869387	leong chan fatt	\N
502	37530157-4336-4122-bdec-d3f7f218aab5	1	1	\N	Sarah Lynn Chin	\N	60178609979	t	2025-11-12 01:11:50.900099	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORENOS SDN BHD", "position": "HR EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.849011	2025-11-12 01:11:50.900841	\N	60178609979	sarah lynn chin	\N
797	bd84bff2-4036-4dd2-bd9e-b1860bce015c	1	1	\N	Fazierah Binti Zulkarnain	fransria86@gmail.com	60163873347	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Riaeira pearl craft ", "position": "Pearl ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:33:51.624427	2025-11-07 02:33:51.624427	fransria86@gmail.com	60163873347	fazierah binti zulkarnain	\N
513	64fce167-b10a-4f64-914f-20b088400907	1	1	\N	Shelly Binti Abdulnally	\N	601126741867	t	2025-11-07 00:15:26.812227	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "DHIYA FOOD INDUSTRIES", "position": "PENGARAH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.897644	2025-11-07 00:15:26.812971	\N	601126741867	shelly binti abdulnally	\N
495	f37efc4f-e8a6-4027-bffd-580575f3a5c8	1	1	\N	Sapphire	\N	60197932156	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Cahaya Metro Sdn Bhd", "position": "Project Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.807606	2025-11-06 02:23:46.807606	\N	60197932156	sapphire	\N
496	4516d9d3-c620-4c0b-9244-49b88c1465e9	1	1	\N	Danny Wong	\N	60128388488	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "WTW Real Estate (S) Sdn Bhd", "position": "Market Consultant", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.812469	2025-11-06 02:23:46.812469	\N	60128388488	danny wong	\N
497	e321568c-774e-4f00-9539-9ee230f3e14b	1	1	\N	Sammy Loo	\N	60168487005	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Cloud Crafters", "position": "Graphic Designer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.816479	2025-11-06 02:23:46.816479	\N	60168487005	sammy loo	\N
498	d988eb17-4e89-4e63-ac09-9912be230225	1	1	\N	Nora Martin	\N	60189735673	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LKNS", "position": "Managment", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.821084	2025-11-06 02:23:46.821084	\N	60189735673	nora martin	\N
499	fa140c45-2025-4ccf-b1b5-f865e840fe13	1	1	\N	Judeth John Baptist	\N	60138602088	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Persatuan SEAMEX Sabah", "position": "President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.828641	2025-11-06 02:23:46.828641	\N	60138602088	judeth john baptist	\N
501	0fb9aa16-566e-4830-bb51-689e07d6c8b0	1	1	\N	Sheila Avril Sipik	\N	601133233678	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Persatuan SEAMEX Sabah", "position": "Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.843426	2025-11-06 02:23:46.843426	\N	601133233678	sheila avril sipik	\N
796	91387326-abe0-4861-90d2-3da2780b196a	1	1	\N	Georgina Reyes Chia	Jreyes8131@gmail.com	60182073669	t	2025-11-07 02:33:41.540808	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Maisarah Time Enterprise ", "position": "Assistance ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:33:41.540808	2025-11-07 02:33:41.540808	jreyes8131@gmail.com	60182073669	georgina reyes chia	\N
503	34161b02-63d8-4683-b860-fd4c7d3164ee	1	1	\N	Sebastian Beltran	\N	60129689575	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Verdant Solar", "position": "Sales Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.854201	2025-11-06 02:23:46.854201	\N	60129689575	sebastian beltran	\N
504	4ba43c3a-ff3c-4c8e-8186-8346a1b1c35b	1	1	\N	Sairah Indan	\N	60138560800	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Sumuni SDN BHD - KDCA", "position": "Managing Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.859285	2025-11-06 02:23:46.859285	\N	60138560800	sairah indan	\N
505	10d881da-2576-418c-b754-2a5e35f4da2c	1	1	\N	Nur Sholeha Binti Mastan	\N	60128317276	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "student", "position": "none", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.863216	2025-11-06 02:23:46.863216	\N	60128317276	nur sholeha binti mastan	\N
506	7ef1166b-97ca-4bd3-88f9-25dcbbb4785d	1	1	\N	Eve Masuil	\N	60149130131	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Student", "position": "None", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.867662	2025-11-06 02:23:46.867662	\N	60149130131	eve masuil	\N
507	e2df84a1-41b9-424a-9552-147524450ff6	1	1	\N	Scholastica Elvera Gidius	\N	60165825638	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "KEMENTERIAN PENDIDIKAN MALAYSIA", "position": "TEACHER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.872058	2025-11-06 02:23:46.872058	\N	60165825638	scholastica elvera gidius	\N
508	edd6b213-ba88-423d-8331-1662cca720ec	1	1	\N	Hazel Hilary	\N	60148543525	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BELIAN JUTA SDN BHD", "position": "PROTEGE (Administrative)", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.876203	2025-11-06 02:23:46.876203	\N	60148543525	hazel hilary	\N
509	4f75c6db-d6c0-4ece-b92c-3f0ca31e6415	1	1	\N	Chong Ming Fung	\N	60146733571	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Entrepreneur", "position": "marketing & freelancer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.880667	2025-11-06 02:23:46.880667	\N	60146733571	chong ming fung	\N
510	1cbcd683-a4b6-437c-a87e-7752c0719a82	1	1	\N	Monica Voo Yu Fang	\N	60138011457	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Borneo wonder holidays", "position": "Coach", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.884806	2025-11-06 02:23:46.884806	\N	60138011457	monica voo yu fang	\N
511	a114e7cb-9a6b-4d7d-ad08-ca6d0216049b	1	1	\N	Ag Mohd Amir Syukri Bin Ag Marjoki	\N	601139000190	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Student", "position": "none", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.889289	2025-11-06 02:23:46.889289	\N	601139000190	ag mohd amir syukri bin ag marjoki	\N
798	5ba0b6f3-3a9f-4189-8279-a99177c62984	1	1	\N	Belle Ethel Yap	Belleethel2002@gmail.com	60189607857	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sabah institute of art", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:37:13.062037	2025-11-07 02:37:13.062037	belleethel2002@gmail.com	60189607857	belle ethel yap	\N
500	f5abc24b-2361-4637-8d11-41bba471627d	1	1	\N	Melvin Jr. Stephen John	\N	60102842343	t	2025-11-07 00:11:36.566865	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Persatuan SEAMEX Sabah", "position": "Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.836189	2025-11-07 00:11:36.567576	\N	60102842343	melvin jr. stephen john	\N
527	e0cb0f7b-7cfb-4269-9e01-1ba6c82fde47	1	1	\N	Chee Ying Ying	\N	60128641009	t	2025-11-12 01:09:04.143734	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORENOS SDN BHD", "position": "FINANCE MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.948782	2025-11-12 01:09:04.14453	\N	60128641009	chee ying ying	\N
800	675523d0-5d58-4748-8d17-3c35e2988fcc	1	1	\N	Andi Rini	andirini@btc.com.my	601111276433	t	2025-11-07 02:41:55.24826	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "KUMPULAN BTC ", "position": "Coordinator", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:38:08.733179	2025-11-07 02:41:55.248915	andirini@btc.com.my	601111276433	andi rini	\N
515	6acb19f4-dec8-43b3-970c-815772fe06e5	1	1	\N	Bryant Wong	\N	60128337368	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "info trader", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.905536	2025-11-06 02:23:46.905536	\N	60128337368	bryant wong	\N
1216	fb145f07-91dd-4629-a028-079c152a1b69	1	3	\N	Chin Fui Tze	\N	60168309386	t	2025-11-08 00:20:12.191366	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "PUMM", "position": "EDUCATION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 00:19:34.032642	2025-11-12 00:11:58.48287	\N	60168309386	chin fui tze	\N
214	88599111-45ac-4b65-abff-a2a96b7f5823	1	1	\N	Dr Yap	\N	016-877 5757	t	2025-11-05 08:17:57.997298	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "CRAZY MIC", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 09:00:36.624386	2025-11-11 07:29:23.736586	\N	0168775757	dr yap	\N
973	e41fd3ba-9dc0-477b-9774-8f30699f32b9	1	1	\N	Fiona Nahor	fionanahor10@gmail.com	60109441477	t	2025-11-07 06:00:05.772411	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MESSENGERCO", "position": "EXHIBITOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:59:34.018826	2025-11-07 06:00:05.773246	fionanahor10@gmail.com	60109441477	fiona nahor	\N
519	e0424baa-deaa-4685-b372-636a73897811	1	1	\N	Immanuel Andingi	\N	60148631657	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "WELDING TRAINER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.920002	2025-11-06 02:23:46.920002	\N	60148631657	immanuel andingi	\N
520	72f05a59-b20e-445e-b904-015e7933b643	1	1	\N	Flory Victoria Matius	\N	601112075736	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "ADMINISTRATIVE ASSISTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.923418	2025-11-06 02:23:46.923418	\N	601112075736	flory victoria matius	\N
521	6d99f94c-ce21-4ad4-9f27-50cfa0dabe64	1	1	\N	Effi Nur Shazleen Binti Salleh	\N	601131482206	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "ADMINISTRATIVE ASSISTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.926697	2025-11-06 02:23:46.926697	\N	601131482206	effi nur shazleen binti salleh	\N
522	6b4313cf-97f7-45de-a1aa-48815d59e0b7	1	1	\N	Ernie Syufina Chun Lee @ Mohd Fadzlee	\N	60109576573	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "ADMINISTRATIVE ASSISTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.930293	2025-11-06 02:23:46.930293	\N	60109576573	ernie syufina chun lee @ mohd fadzlee	\N
523	43eca526-452e-4405-8de3-84c1da2c646c	1	1	\N	Linus Joseph	\N	60192856231	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "OIL PALM PLANTATION TRAINER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.934253	2025-11-06 02:23:46.934253	\N	60192856231	linus joseph	\N
524	2d1fb209-6806-4255-88d5-20d9a0e94fff	1	1	\N	Mohammad Alif Bin Abdullah	\N	60197071907	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lados sdn bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.937635	2025-11-06 02:23:46.937635	\N	60197071907	mohammad alif bin abdullah	\N
525	428b4ebc-c557-4234-9c96-6ccf1ebd45b7	1	1	\N	Fung Siew Nie @anny	\N	60143753437	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "KK CHOCOLATE HOUSE SDN BHD", "position": "Accounts & Administrative Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.941478	2025-11-06 02:23:46.941478	\N	60143753437	fung siew nie @anny	\N
526	8c0b4ca7-2b92-4205-832d-ac6fe1d938ee	1	1	\N	Jalina Jahari	\N	601119583166	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "YULY GLOBAL INTERNATIONAL SDN.BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.944939	2025-11-06 02:23:46.944939	\N	601119583166	jalina jahari	\N
528	7970301d-71bd-4233-93e4-cfe4d8ed2495	1	1	\N	Jaccie Koh	\N	60164646392	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Invest Sabah Berhad", "position": "Head of Marketing and Corporate Communications", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.952747	2025-11-06 02:23:46.952747	\N	60164646392	jaccie koh	\N
529	175887b1-df03-4f49-9acf-2ff0948d4931	1	1	\N	Alec Eng	\N	60198219713	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Cher Borneo pearl", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.956747	2025-11-06 02:23:46.956747	\N	60198219713	alec eng	\N
530	3dc90b7b-2efb-41fd-9e9f-b973d14a8e97	1	1	\N	Mellisa Lee Shao Fei	\N	60178188361	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "POIC Sabah Sdn Bhd", "position": "Senior Executive, Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.96079	2025-11-06 02:23:46.96079	\N	60178188361	mellisa lee shao fei	\N
531	6cf5a699-f2c0-46bd-ae88-f39cf0a284d8	1	1	\N	Shidi Dahlan	\N	60128697307	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME Corp Malaysia Negeri Sabah", "position": "Pembantu Eksekutif / Pegawai Khas Pengerusi SME Corp Malaysia", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.964841	2025-11-06 02:23:46.964841	\N	60128697307	shidi dahlan	\N
516	bca6f319-1156-4e7e-ac65-ac9b4ba39337	1	1	\N	Derrick Tan	\N	60124814006	t	2025-11-12 00:05:31.295702	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "S & J BAR CODE SDN BHD", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.909191	2025-11-12 00:05:31.296508	\N	60124814006	derrick tan	\N
518	54615833-69a7-4d03-ae0d-7e945d7a0358	1	1	\N	Eveiynne Galigeh	eveiynn.sstc@gmail.com	60198696277	t	2025-11-06 23:51:24.847522	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "CORPORATE DEVELOPMENT EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.916322	2025-11-06 23:51:24.848067	eveiynn.sstc@gmail.com	60198696277	eveiynne galigeh	\N
532	51dc48eb-0202-4f1b-bf10-8bc3e8501b3f	1	1	\N	Veve Lo	\N	60168024426	t	2025-11-07 03:36:30.937876	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "POIC Sabah Sdn Bhd", "position": "Manager, Business Development", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.968727	2025-11-07 03:36:30.938462	\N	60168024426	veve lo	\N
546	f0764b23-88e7-4f50-8b30-0df05399ec7c	1	1	\N	Matthews Aziz	\N	60128032088	t	2025-11-07 00:35:30.777308	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.404584	2025-11-07 00:35:30.777941	\N	60128032088	matthews aziz	\N
238	3c0a31b4-6488-4cdd-82f2-d7a57f922a7a	1	7	\N	Joseph Benjamin	\N	\N	t	2025-11-05 10:21:30.891893	23	1	1	\N	\N	\N	{"role": "VIP", "company": "MIDA", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:02:42.858637	2025-11-05 10:21:30.89272	\N	\N	joseph benjamin	\N
418	de52159e-4fc2-45a6-abf2-8bbfc318fc12	1	1	\N	Eleysa Emily Huil	\N	60145503947	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Phi Software Sdn. Bhd.", "position": "System Analyst", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.063615	2025-11-06 02:23:46.063615	\N	60145503947	eleysa emily huil	\N
1289	4ea7c29e-8e6b-41ac-8492-73fa960bef49	1	1	\N	Chong Kai Khiun	chongkk@kianlon.edu.my	60168363398	t	2025-11-08 00:56:19.977992	29	1	1	\N	\N	\N	{"role": "Lecturer", "company": "Kian Kok Middle School"}	2025-11-08 00:55:31.83729	2025-11-08 00:56:19.978628	chongkk@kianlon.edu.my	60168363398	chong kai khiun	\N
472	7cbd9abc-8c74-4264-b2e1-1cc2366b38b4	1	1	\N	Nazihah Binti Hasan	\N	60138924468	t	2025-11-12 01:24:57.924976	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "ACCOUNTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.634822	2025-11-12 01:24:57.925667	\N	60138924468	nazihah binti hasan	\N
542	aa1b40b8-9829-49d6-b695-41fe55006dc8	1	7	\N	Datuk Jonathan Koh, Jp	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "Sabah China Chamber of Commerce", "position": "Vice President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.293733	2025-11-06 14:44:16.293733	\N	\N	datuk jonathan koh, jp	\N
543	679cc721-3781-4f72-a9e8-f2592c3886c0	1	7	\N	Mr Hong Jia Hao	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "Sabah China Chamber of Commerce", "position": "COMMITTEE MEMBER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.3796	2025-11-06 14:44:16.3796	\N	\N	mr hong jia hao	\N
544	c698af37-1e08-436b-8ce2-a39edb7de4d4	1	7	\N	Jeffry Salleh	\N	60128669695	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "Phi Software Sdn. Bhd.", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.388136	2025-11-06 14:44:16.388136	\N	60128669695	jeffry salleh	\N
545	5cd02820-9c47-4e4b-9da1-a220c820954b	1	1	\N	Samantha Chin Si Ying	\N	60109420195	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SIA", "position": "INTERNATIONAL AFFAIRS DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.397382	2025-11-06 14:44:16.397382	\N	60109420195	samantha chin si ying	\N
552	842af2c0-381f-4e1c-8e52-1e558d657d23	1	2	\N	Cherise	\N	60172288943	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Tiktok Shop", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.501206	2025-11-06 17:26:26.756732	\N	60172288943	cherise	\N
547	4e8f5c46-509a-406f-8a04-3dc4270642b4	1	7	\N	Ms Norazilah Mohamad	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "SIRIM", "position": "EXECUTIVE SIRIM SABAH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.413658	2025-11-06 14:44:16.413658	\N	\N	ms norazilah mohamad	\N
548	3e7fac05-9baf-48b4-bce6-6e158c9cf796	1	7	\N	Puan Izabella Kiki Apat	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "SIRIM", "position": "EXECUTIVE SIRIM SABAH", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.423598	2025-11-06 14:44:16.423598	\N	\N	puan izabella kiki apat	\N
549	9d45b423-61c7-4767-8844-a874e096adfb	1	7	\N	Puan Herni Munir	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "SME CORPORATION MALAYSIA", "position": "SENIOR EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.433453	2025-11-06 14:44:16.433453	\N	\N	puan herni munir	\N
550	2a2d58d5-374d-4631-9b64-bd91a1b17541	1	7	\N	Ms Vivien Thien	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "MIDA", "position": "ASSISTANT EXECUTIVE OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.442822	2025-11-06 14:44:16.442822	\N	\N	ms vivien thien	\N
551	2fb585a6-d637-4038-92f6-c8bc1b4c6afc	1	7	\N	Puan Lydiana G. Kasun	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VIP", "company": "TERAJU, SABAH", "position": "EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.45299	2025-11-06 14:44:16.45299	\N	\N	puan lydiana g. kasun	\N
1290	99936cb3-b163-4ec3-92b5-dbfa3048608a	1	3	\N	Malisa Ganit	\N	60122087696	t	2025-11-08 00:56:35.575799	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kawasku", "position": "Co Founder"}	2025-11-08 00:56:16.822685	2025-11-08 00:56:35.576299	\N	60122087696	malisa ganit	\N
514	212bfe0a-f3bb-44d3-b2e6-e66b0fd5f3ef	1	1	\N	Janice Yeo	\N	60123288311	t	2025-11-12 00:41:52.067256	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORENOS SDN BHD", "position": "MANAGING DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.901807	2025-11-12 00:41:52.068086	\N	60123288311	janice yeo	\N
554	57161ddc-1d42-4c6d-8bd9-831bac71641a	1	2	\N	Cassandra Villafane	\N	60148530483	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Casey's Cafe (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.524435	2025-11-06 17:26:49.959127	\N	60148530483	cassandra villafane	\N
553	ee423ad8-88f6-4236-99c0-37ed2d23b431	1	2	\N	Satinun Binti Tambasal	\N	60133203525	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "King Kong Tech (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.509619	2025-11-06 17:26:18.045872	\N	60133203525	satinun binti tambasal	\N
561	e2caa5db-3318-4534-8fef-bdc5584e11fa	1	2	\N	Norsiah Binti Ahiddin	\N	60143519675	t	2025-11-06 23:36:13.548542	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Norcy Beautylab Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.583337	2025-11-06 23:36:13.549117	\N	60143519675	norsiah binti ahiddin	\N
560	4b204a0c-0265-4732-b20b-c48baa90698d	1	2	\N	Rosmah Ajumarih	\N	60168026454	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Rass Entreprise - Jus Bambangan (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.574336	2025-11-06 17:26:39.679412	\N	60168026454	rosmah ajumarih	\N
555	69d66e59-5819-4eab-aef0-2875beb5c645	1	2	\N	Rafidah Binti Jumah	\N	60109510002	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "RDS Juta Food Industries Sdn Bhd (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.533123	2025-11-06 17:26:54.47716	\N	60109510002	rafidah binti jumah	\N
556	d6f596a6-0057-41f4-9938-bdf885378d59	1	2	\N	Hasrah Binti Malik	\N	60105362210	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Millionaire Industries Sdn Bhd (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.543264	2025-11-06 17:26:58.969565	\N	60105362210	hasrah binti malik	\N
805	9f8fb3c5-7c22-4295-b119-091a6b934850	1	1	\N	Jae	jae.neoh@mytecd.com	60124711157	t	2025-11-07 02:40:43.349201	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "Tec D Malaysia", "position": "Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:40:43.349201	2025-11-07 02:44:00.617541	jae.neoh@mytecd.com	60124711157	jae	\N
74	59147308-8f73-4e47-8bb1-e14d8386e00c	1	2	\N	Liviana Jiliew @ Majorie	\N	011-10175025	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Viana Craft & Souvenir (SWEPA)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:14:21.029628	2025-11-06 17:34:07.455895	\N	01110175025	liviana jiliew @ majorie	\N
79	36311d45-a38a-4f7c-a3c5-7982e80648a7	1	2	\N	Fung Zing Yee	\N	010-9000826	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cuckoo International (MAL) Berhad (SWEPA)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:35:52.43234	2025-11-06 17:34:10.749401	\N	0109000826	fung zing yee	\N
563	799dad16-498a-4a73-aaa3-4145ed25a77e	1	2	\N	Anne Antah	\N	60195300018	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "CB SparkLab (Accessories and Souvenir)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.645768	2025-11-06 17:27:44.16583	\N	60195300018	anne antah	\N
82	3785c14a-b382-48d2-aa7f-f476ad5bd06a	1	2	\N	Hamizan Naeem Bin Hazlan	\N	010-6541910	t	2025-11-11 08:51:59.288176	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "HUMANCE", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:36:56.736145	2025-11-11 08:51:59.288937	\N	0106541910	hamizan naeem bin hazlan	\N
1313	d7adf342-8fa5-45bd-afa2-f9df114b8da1	1	1	\N	Cyril Isaac	cyrilisaacdaryl1@gmail.com	60178938764	t	2025-11-08 01:08:58.623008	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 01:08:58.623008	2025-11-08 01:08:58.623008	cyrilisaacdaryl1@gmail.com	60178938764	cyril isaac	\N
809	9e96f014-11b8-417b-a120-37a11fb0986c	1	1	\N	Muhd Irfan Sarin	m.irfansarin@gmail.com	60102217476	t	2025-11-07 02:46:50.034635	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "MIDE", "position": "Assistant Administrative", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:45:08.682145	2025-11-07 02:46:50.035292	m.irfansarin@gmail.com	60102217476	muhd irfan sarin	\N
566	15d10fbe-bb38-4e7c-91ad-93e81a428388	1	2	\N	Mable Wong Hui Qi	\N	60168339342	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Phileo Gelato", "position": "", "coupon_referral": "", "business_industry": "F&B", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.765192	2025-11-06 17:33:28.724608	\N	60168339342	mable wong hui qi	\N
186	df12f777-4589-4173-9aa5-63f525fcfc20	1	3	\N	Janice Lee Syn Tian	\N	01110081177	t	2025-11-07 08:57:08.016736	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "Students", "coupon_referral": "", "business_industry": "Education", "print_exhibitor_tag": ""}	2025-11-03 08:03:54.259814	2025-11-07 08:57:08.0174	\N	01110081177	janice lee syn tian	\N
128	ddf8b59b-8a96-44cd-9864-eba34311620d	1	1	\N	CHONG VUI FAH @ WILLIAM CHONG	\N	010-9445522	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "PROJECT DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:04:24.354958	2025-11-03 06:04:24.354958	\N	0109445522	chong vui fah @ william chong	\N
136	631f40c4-2b67-45bd-a12f-1f3af9dc9a86	1	1	\N	CHUA CHIN SOON	\N	010-9312293	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "TWO THOUSAND AND ONE COMPUTER (M) SDN BHD", "position": "PROJECT DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:44:51.260972	2025-11-03 06:44:51.260972	\N	0109312293	chua chin soon	\N
573	99437e7f-8ed7-4be5-945e-492eaf7b2912	1	2	\N	Eriy Binti Dusun	\N	60197964170	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hal Ehwal Wanita", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.852594	2025-11-06 14:44:16.852594	\N	60197964170	eriy binti dusun	\N
574	a6137227-7483-4482-843a-6317d10c7288	1	2	\N	Inayan Binti Nudding	\N	60198077070	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hal Ehwal Wanita", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.862202	2025-11-06 14:44:16.862202	\N	60198077070	inayan binti nudding	\N
575	e9dac671-149e-4898-9a5f-f9f68ea56931	1	2	\N	Shelly Binti Adbul Nelly	\N	601126741867	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hal Ehwal Wanita", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.872746	2025-11-06 14:44:16.872746	\N	601126741867	shelly binti adbul nelly	\N
564	883e2bf5-c6a7-4c3f-9c02-65ec92682b41	1	2	\N	Norainie	\N	601139877511	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cahya Matha Entreprise (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.675877	2025-11-06 17:30:31.390201	\N	601139877511	norainie	\N
565	c702547d-66f3-43b1-b2e0-14b6fb87ff82	1	2	\N	Liza Muiz	\N	60198323679	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Nyonya KB", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.707947	2025-11-06 17:33:03.903437	\N	60198323679	liza muiz	\N
567	975e3a12-9cd3-4660-86ad-9503850e71eb	1	2	\N	Nasriah Abdullah	\N	60168178716	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cahaya Nur Adhwa", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.796429	2025-11-06 17:33:37.935585	\N	60168178716	nasriah abdullah	\N
569	7994ac44-adfd-4af7-a6c0-8230783eea06	1	2	\N	Sarmini Sarman	\N	60145720901	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hal Ehwal Wanita", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.811639	2025-11-07 05:03:58.83999	\N	60145720901	sarmini sarman	\N
570	0d9c8736-c373-4996-9c74-6d13234a2d71	1	2	\N	Dorren Binti Molium	\N	60198011082	t	2025-11-07 02:38:41.010644	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hal Ehwal Wanita", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.82054	2025-11-07 02:38:41.011276	\N	60198011082	dorren binti molium	\N
572	47abb771-a833-40f1-bfea-c7127965d9c8	1	2	\N	Maria	\N	60178338578	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hal Ehwal Wanita", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.838233	2025-11-06 17:35:05.409329	\N	60178338578	maria	\N
833	c7290ed1-9ed7-412e-8c8d-4e69859b906b	1	1	\N	Amtc - Jessie	jessiewong0501@gmail.com	60128460733	t	2025-11-07 03:06:30.669145	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "AMTC SYSTEM SDN BHD ", "position": "Sales executive ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:05:47.317227	2025-11-07 03:06:30.669745	jessiewong0501@gmail.com	60128460733	amtc - jessie	\N
950	de959312-6393-41fd-b69c-f38b2748f7af	1	1	\N	Lizah Sani	Lizarich1303@gmail.com	60125669607	t	2025-11-07 05:22:39.446325	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lados ", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:22:07.389797	2025-11-07 05:22:39.447128	lizarich1303@gmail.com	60125669607	lizah sani	\N
97	c83b1329-66af-49cd-b856-ae4dcd93c0f5	1	3	\N	Kun Tet Jin @ Voca	\N	0109301915	t	2025-11-07 08:56:59.148755	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": "Head Of Sales ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 10:20:46.737091	2025-11-07 08:56:59.149509	\N	0109301915	kun tet jin @ voca	\N
1217	cca87d66-e494-4165-80c2-f07a06ceb21b	1	3	\N	Lily Wong Bitt Lee	\N	60198807348	t	2025-11-08 00:20:36.95045	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kkhs", "position": "Principal"}	2025-11-08 00:19:43.991016	2025-11-08 00:20:36.951124	\N	60198807348	lily wong bitt lee	\N
599	96ced85b-f923-45c3-923e-649bae90d7f4	1	1	\N	Ms Noorziah	\N	60198603627	t	2025-11-11 07:17:48.529619	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "KINABALU HANDMADE CHOCOLATE", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.17737	2025-11-11 07:17:48.530335	\N	60198603627	ms noorziah	\N
581	409568df-768e-4049-90e3-ddccb2c4a839	1	2	\N	Amanda	\N	60199333337	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "KKIP SDN BHD", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.989828	2025-11-12 00:31:19.061194	\N	60199333337	amanda	\N
586	5e45b42e-9207-4d92-a794-0202984f79d5	1	2	\N	Chang Kok Kien	\N	60168405000	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "SABAH CREDIT CORPORATION", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.057471	2025-11-12 00:36:30.908097	\N	60168405000	chang kok kien	\N
40	da12d942-8251-4059-9c21-a716c85584dc	1	2	\N	Vanessa	\N	010-2101373	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hainan Properties Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:09:26.389981	2025-11-06 17:35:40.733342	\N	0102101373	vanessa	\N
576	1aa0a472-41ef-453b-a996-1aed5d876eb4	1	2	\N	Mr. Gopal	\N	60167121135	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "CHEF EG - SRI WARAS", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.882602	2025-11-06 17:35:31.852695	\N	60167121135	mr. gopal	\N
577	3eaa01fb-4d69-4008-8ddb-481ea67dfbe9	1	2	\N	Tn Charis Saliun	\N	6089569198	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "SKG GREEN SDN BHD", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.894334	2025-11-06 17:36:32.393981	\N	6089569198	tn charis saliun	\N
579	eccbcfe1-c5a9-49fc-83e8-eea590866231	1	2	\N	Kalvin Chuah	\N	60162398919	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Evo Microsoft", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.95199	2025-11-06 17:35:45.043556	\N	60162398919	kalvin chuah	\N
580	9a3aca92-e996-4089-a7e5-aa1d8e602641	1	2	\N	Anna Liew	\N	60168303994	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Mega City Builder Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.975949	2025-11-06 17:35:49.560516	\N	60168303994	anna liew	\N
582	a5a9fb68-fcf0-41a3-8386-fc06d3813afe	1	2	\N	Rustam	\N	60138970988	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Kenny", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.00256	2025-11-06 17:36:45.072266	\N	60138970988	rustam	\N
584	cee4d204-7f7f-4e90-ab2e-04af1db27ada	1	2	\N	Te Chin Yong	\N	60123166995	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Xplosure Production", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.041707	2025-11-06 17:36:48.347514	\N	60123166995	te chin yong	\N
585	3a3e0182-9a86-4b5e-b729-fdef027bba3d	1	2	\N	Chealsea	\N	60128276883	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Prime Deco", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.050794	2025-11-06 17:36:52.005853	\N	60128276883	chealsea	\N
588	58fd8b2c-3494-4c4b-9706-cd244d31f46f	1	2	\N	Pn Damaris	\N	601131662318	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Kebudayaan Lundayeh Sabah ( PKLS)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.068729	2025-11-06 17:37:03.680672	\N	601131662318	pn damaris	\N
589	e40e4c2e-1ad3-4e55-b0fc-78495bbbb67c	1	2	\N	Pn Nola Eri Abdullah	\N	60168021672	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Kinuama Tuntuu Lola", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.079766	2025-11-06 17:37:06.544544	\N	60168021672	pn nola eri abdullah	\N
590	1268210f-3773-4c2f-8385-1ac09b3282cc	1	2	\N	Datuk Hj. Abdullah B. Hj.sibil	\N	60128271071	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Sama Sabah (PSS)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.090727	2025-11-06 17:37:13.909166	\N	60128271071	datuk hj. abdullah b. hj.sibil	\N
591	14018e16-0b40-464a-bc08-fa4f62fe2bc4	1	2	\N	Sairah Indan	\N	60138560800	t	2025-11-07 00:29:03.019184	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "KDCA", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.100423	2025-11-07 00:29:03.01988	\N	60138560800	sairah indan	\N
593	42e47a34-185b-4005-9e0f-6a314cc47cdb	1	2	\N	Datu Fazil Bin Datu Ajak	\N	601126023288	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Pertubuhan Profesional Suluk Sabah (PROS)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.118678	2025-11-06 17:37:20.640517	\N	601126023288	datu fazil bin datu ajak	\N
594	c82bb3c6-3fb6-4216-9202-ddd1318d4789	1	2	\N	Oneh & Latifah Bt Osman	\N	60147732863	t	2025-11-07 00:16:27.942124	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Pertubuhan Kimaragang Malaysia", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.129342	2025-11-07 00:16:27.942741	\N	60147732863	oneh & latifah bt osman	\N
597	a106d0af-2cb7-4fb8-a87b-9a7ef6190dee	1	2	\N	Malin Binti Soborong	\N	60108861828	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Molins Kraf Enterprise", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.157708	2025-11-06 17:37:31.408515	\N	60108861828	malin binti soborong	\N
598	408dc62a-d770-4f21-ba7b-d402230da3c7	1	2	\N	Ms Jullizah	\N	60162949065	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Insprise Top Global", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.166954	2025-11-06 17:37:34.602657	\N	60162949065	ms jullizah	\N
807	01fba5a5-93b6-4d9e-9020-cb9247e5e339	1	1	\N	Don Stephens	Donstep68@gmail.com	60168309996	t	2025-11-07 02:42:29.000479	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "S ENERGY SOLUTIONS ", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:41:54.493991	2025-11-07 02:42:29.00191	donstep68@gmail.com	60168309996	don stephens	\N
808	36de5b68-42b6-4605-9f43-59faeb0bff86	1	1	\N	Wilson Gan	wilsongan2000@yahoo.com	60168389320	t	2025-11-07 02:45:37.296787	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "GW Farms", "position": "Owner Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:42:17.77307	2025-11-07 02:45:37.297447	wilsongan2000@yahoo.com	60168389320	wilson gan	\N
810	1501feb4-071e-4bd9-80e7-bc4537ce8e4b	1	1	\N	Mohd. Ezhmil Bin Santi	Mohdezhmil.santi@sabah.gov.my	60145682619	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "MIDE", "position": "Assistant Information Technology Officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:45:44.159577	2025-11-07 02:45:44.159577	mohdezhmil.santi@sabah.gov.my	60145682619	mohd. ezhmil bin santi	\N
1183	e81683da-3330-478d-a7a5-e7f8cfa795f3	1	3	\N	Wyatt Hendricks	tokeqa@mailinator.com	+1 (632) 769-6836	t	2025-11-07 10:01:06.767002	\N	1	1	\N	\N	\N	{"role": "Omnis quis voluptate", "company": "Tempore veniam rer", "position": "Aut praesentium est", "coupon_referral": "Ipsa ad rem recusan", "business_industry": "Hic autem quos non q", "print_exhibitor_tag": "In veritatis aut quo"}	2025-11-07 10:01:01.520811	2025-11-07 10:01:06.767738	tokeqa@mailinator.com	16327696836	wyatt hendricks	\N
708	499e6f52-6f51-45e4-86c0-e7212fc45d6f	1	1	\N	Rohana Teo	nanateo01@gmail.com	60178337313	t	2025-11-07 00:07:25.285468	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Research", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:07:25.285468	2025-11-07 00:07:25.285468	nanateo01@gmail.com	60178337313	rohana teo	\N
600	b1d391f7-6175-44d4-bf9b-8c97f6e2b434	1	2	\N	Ms Juliana	\N	60178587301	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Norizz D'Hati", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.184486	2025-11-06 17:37:41.650904	\N	60178587301	ms juliana	\N
602	0e4f4105-e513-4eee-96a7-522b0bd9a11f	1	2	\N	Mr Benjamin	\N	60198527586	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Simply Chocolate Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.20691	2025-11-06 17:38:15.241035	\N	60198527586	mr benjamin	\N
603	94ef92f7-a4dc-4d51-b826-2842e2e4f0a5	1	2	\N	Jack	\N	60109195121	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Universal Motor", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.215225	2025-11-06 17:38:25.637338	\N	60109195121	jack	\N
605	7d2a594e-213d-498d-9e6e-91b77413a630	1	2	\N	Lim Chee How	\N	601112126966	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Tapway", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.262431	2025-11-06 17:38:37.518284	\N	601112126966	lim chee how	\N
604	bcf6d614-9dc0-4796-ba7f-4b1a487a3c19	1	2	\N	Daniel Wong	\N	60172797877	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Skai Lab Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.254094	2025-11-06 17:38:18.840936	\N	60172797877	daniel wong	\N
607	1f1e6b01-7d23-4eba-9a69-da861fdcbdee	1	2	\N	Gennie Tsu	\N	886989618390	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ace Star Media Yuenviet AI, Taiwan", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.306174	2025-11-06 17:38:45.337762	\N	886989618390	gennie tsu	\N
608	c8df23f1-b2e9-43c9-931f-484be2607b6e	1	2	\N	Karen	\N	60138641215	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Karen Make up", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.337693	2025-11-06 17:38:51.771271	\N	60138641215	karen	\N
609	6ed42afe-a8d2-48a2-86b5-efcbfec2bd07	1	2	\N	Ivy Stephenie	\N	60168667515	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Penview Hotel & Seri Simanggang", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.346162	2025-11-06 17:38:57.18234	\N	60168667515	ivy stephenie	\N
610	15eb30c5-035f-4c4a-8ff8-517d29b712b2	1	2	\N	Carmen	\N	60168801105	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Piel Perfecta", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.355595	2025-11-06 17:41:04.506771	\N	60168801105	carmen	\N
612	f51b828b-f5ba-4184-9d5b-b26af6d07780	1	2	\N	Diyana	\N	60128182203	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Meat.BKI_BurgCraft", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.376617	2025-11-06 17:41:09.270431	\N	60128182203	diyana	\N
613	7b8a1805-7713-4814-a309-c38927f289ef	1	2	\N	Kendy Yeong	\N	601118985757	t	2025-11-07 04:21:13.049316	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Crazy Mic", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.386648	2025-11-07 04:21:13.050085	\N	601118985757	kendy yeong	\N
614	3ed14031-999a-461f-a0c3-0c3789d6bae3	1	2	\N	Anneesh	\N	60123311246	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cinnamonkins", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.396973	2025-11-06 17:41:18.961721	\N	60123311246	anneesh	\N
617	71bc573a-f1a7-4342-9027-6ad848a997a9	1	2	\N	Jescynthia Janett	\N	60199818640	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "RipOff Printism - Printing Services", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.423217	2025-11-06 17:43:10.828305	\N	60199818640	jescynthia janett	\N
618	5d1f4414-343a-4340-ad70-3d837bfbab7e	1	2	\N	Enja Manie	\N	60109155878	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Quality Confinement Home", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.433854	2025-11-06 17:43:14.29833	\N	60109155878	enja manie	\N
620	d1e7a4bd-0ded-4212-8c1a-63fa8782f0a7	1	2	\N	Nicole Leong	\N	60168100909	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Niclovehandmade", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.457363	2025-11-06 17:43:20.388886	\N	60168100909	nicole leong	\N
622	57d451fb-4fe7-4579-abdc-64e6c3a9c00b	1	2	\N	Qiqi Leong	\N	60129529598	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "YOU YUAN LAI DESSERTS", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.476242	2025-11-06 17:43:26.634496	\N	60129529598	qiqi leong	\N
623	701a516b-9d9a-4d9b-b18e-a00f6d0dc31b	1	2	\N	Nieyna	\N	60135196765	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "BOY EMPIRE ENTERPRISE", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.483039	2025-11-06 17:43:29.419697	\N	60135196765	nieyna	\N
707	d846d129-4639-4b5d-9365-8d26f49b02c6	1	1	\N	Penny Sin	penny@kimanisfood.com.my	60165093086	t	2025-11-07 00:09:24.336398	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kimanis Food Industries Sdn Bhd ", "position": "Account Executive ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:07:16.316133	2025-11-07 00:09:24.336994	penny@kimanisfood.com.my	60165093086	penny sin	\N
711	5f2908bd-7a8f-43a9-ab63-92be0d0ee379	1	1	\N	James Lee Yong Xing	jlyx05@gmail.com	60168308686	t	2025-11-07 00:12:23.530023	23	1	1	\N	\N	\N	{"role": "Student", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:15.788053	2025-11-07 00:12:23.530796	jlyx05@gmail.com	60168308686	james lee yong xing	\N
712	6ae6ebb5-0a28-4ea6-aea1-879e4e905ce1	1	1	\N	Liau Li Wen	liaulw@gmail.com	60168050792	t	2025-11-07 00:12:15.829958	23	1	1	\N	\N	\N	{"role": "Student", "company": "TARUMT ", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:16.406638	2025-11-07 00:12:15.830617	liaulw@gmail.com	60168050792	liau li wen	\N
846	5145669b-77a4-46e3-91b5-75ce6a4a6f0c	1	1	\N	Stephen Siaw	llithbakery@gmail.com	60167097375	t	2025-11-07 03:12:43.621016	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Llith Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:12:22.608567	2025-11-07 03:12:43.621587	llithbakery@gmail.com	60167097375	stephen siaw	\N
732	28e66168-e510-4dcc-9192-08e7d8a2d8ff	1	1	\N	Valenie	valenie.wsg@gmail.con	60109427325	t	2025-11-07 00:13:03.980293	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG PROPERTIES SDN BHD", "position": "HUMAN RESOURCES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:12:12.245391	2025-11-12 01:26:25.707667	valenie.wsg@gmail.con	60109427325	valenie	\N
1218	6801ae3f-f116-4e41-9eba-e00b37d6dc66	1	3	\N	Gavin Chia Chung Yong	\N	60189003873	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property ", "position": "CEO"}	2025-11-08 00:21:27.124519	2025-11-08 00:21:27.124519	\N	60189003873	gavin chia chung yong	\N
710	abaf202f-de97-48bb-b23f-d6c09b3dcda8	1	1	\N	Aqilah Binti Abdullah	Aqilah.Abdullah@sabah.gov.my	60146774777	t	2025-11-07 00:10:14.746615	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ministry of Tourism, Culture and Environment Sabah ", "position": "Government Servant", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:03.347208	2025-11-07 00:10:14.747131	aqilah.abdullah@sabah.gov.my	60146774777	aqilah binti abdullah	\N
764	6942dab2-a8b9-4e03-8bee-90336f124fe6	1	1	\N	Siaw Ten Hon	tenhon@cocoakingdom.com	60128285850	t	2025-11-11 08:29:58.683381	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "COCOA KINGDOM", "position": "MANAGING DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:45.698632	2025-11-11 08:29:58.684132	tenhon@cocoakingdom.com	60128285850	siaw ten hon	\N
741	dfebf49d-3fac-4a38-87ed-d8c40d4d2e84	1	1	\N	Francis Chan	fccl008@gmail.com	60138513836	t	2025-11-07 00:15:35.139829	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SME SABAH", "position": "SECRETARY GENERAL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:14:24.128983	2025-11-12 00:01:31.769166	fccl008@gmail.com	60138513836	francis chan	\N
720	122661cd-df50-455d-8919-171516e5e7c9	1	1	\N	Adrian Alang	aad7702@gmail.com	601125758974	t	2025-11-07 00:11:18.576047	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SEDCO", "position": "IT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:10:15.025693	2025-11-07 00:11:18.576746	aad7702@gmail.com	601125758974	adrian alang	\N
721	8c1b75bb-c68b-4811-bc5d-2674f56ce48a	1	1	\N	Immanuel Andingi	Nuel.sstc@gmail.com	60148631657	t	2025-11-07 00:10:58.699562	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Skills & Technology Centre", "position": "Trainer - Welding", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:10:34.108253	2025-11-07 00:10:58.700277	nuel.sstc@gmail.com	60148631657	immanuel andingi	\N
766	2c3bfe63-1d8a-42c4-9068-883a2bc1b189	1	1	\N	Yap Por Chik	smesabah@yahoo.com	60199690072	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SME SABAH", "position": "COUNCIL MEMBER CUM DIRECTOR AGRICULTURE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:52.088756	2025-11-12 00:02:29.76573	smesabah@yahoo.com	60199690072	yap por chik	\N
750	c4d07407-72c0-4a32-ae5f-bc60d60f7bd3	1	1	\N	Chai Hui Chet	ah_bung0809@hotmaol.com	601131427389	t	2025-11-07 00:16:38.192521	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Paumin Hardware Sdn Bhd", "position": "Marketing", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:16:38.192521	2025-11-07 00:25:26.766794	ah_bung0809@hotmaol.com	601131427389	chai hui chet	\N
740	e249a70d-438c-4a79-a1c8-43fb7b65288f	1	1	\N	Normegawati Sapian	mega@sabahtourism.com	60128330338	t	2025-11-07 00:18:49.507937	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "SPECIAL OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:14:12.448275	2025-11-12 00:44:53.547362	mega@sabahtourism.com	60128330338	normegawati sapian	\N
742	c49dd2c5-0870-4d02-b2a5-360e8e9672dc	1	1	\N	Maymall Frayneey Kipli	Maydaykipli@gmail.com	60194134674	t	2025-11-07 00:15:15.254254	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah ", "position": "Latihan dan kemahiran", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:14:35.198341	2025-11-07 00:15:15.254969	maydaykipli@gmail.com	60194134674	maymall frayneey kipli	\N
745	8815e97d-e2ff-4db3-8dba-ff4158d1c144	1	1	\N	Pang Yeng Yuan	pangyy@tarc.edu.my	60166683867	t	2025-11-07 00:17:41.498775	23	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TAR UMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:15:23.555488	2025-11-07 00:17:41.499454	pangyy@tarc.edu.my	60166683867	pang yeng yuan	\N
747	9904ff27-fec3-4585-9dd5-557845e0dcd6	1	1	\N	Jalifah	jslady2207@gmail.com	60162207902	t	2025-11-07 00:16:16.426471	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "JHEWA", "position": "promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:15:56.298113	2025-11-07 00:16:16.427047	jslady2207@gmail.com	60162207902	jalifah	\N
748	160f0c0e-38f2-419b-b20b-d3bd16c2e1ed	1	1	\N	Ggm Dr Jes Lim Tyng Yee	Jestylimkk@gmail.com	6088363306	t	2025-11-07 00:16:25.744848	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "FSI", "position": "Founding President ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:16:02.960531	2025-11-07 00:16:25.745377	jestylimkk@gmail.com	6088363306	ggm dr jes lim tyng yee	\N
765	96c32779-83a7-4156-9e06-d18ea78ba48e	1	1	\N	Sandy Chen	sandy.aichang@gmail.com	60168043439	t	2025-11-07 00:19:46.777891	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "G&a group", "position": "Clerk", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:46.777891	2025-11-07 00:19:46.777891	sandy.aichang@gmail.com	60168043439	sandy chen	\N
749	041f4280-43b8-48aa-945a-b780a229a8b5	1	1	\N	Noirom Dony @ Fredolin Dony	noiromdony@tarc.edu.my	60128302666	t	2025-11-07 00:17:51.660944	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:16:28.696233	2025-11-07 00:17:51.661499	noiromdony@tarc.edu.my	60128302666	noirom dony @ fredolin dony	\N
758	1fc50a6e-0266-4adb-950a-d0c45501e857	1	1	\N	Grace Lee Jun Yee	Junyee0808@gmail.com	60168108782	t	2025-11-07 00:18:43.029784	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker tilly LSC PLT", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:18:19.797617	2025-11-07 00:18:43.030503	junyee0808@gmail.com	60168108782	grace lee jun yee	\N
759	98e216bd-3455-47cb-bca6-8a246ebbaae0	1	1	\N	Estherlita Siondom David	estherlitasdm@yahoo.com	601161184632	t	2025-11-07 00:25:55.244728	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SUMUNI SDN BHD (KDCA)", "position": "ADMIN OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:13.827627	2025-11-07 00:25:55.245388	estherlitasdm@yahoo.com	601161184632	estherlita siondom david	\N
762	23eb0923-3fbb-4657-b0ec-fd8b7785fb74	1	1	\N	Jasmine Lim Hui Shi	limjasmine88@gmail.com	60178770213	t	2025-11-07 00:21:18.22258	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cygnus Technology Solutions Sdn Bhd", "position": "Managing Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:44.542703	2025-11-07 00:21:18.223149	limjasmine88@gmail.com	60178770213	jasmine lim hui shi	\N
678	245edeb3-d376-47b8-ae67-3b3e4fb72bb7	1	1	\N	Associate Professor Dr Chin Pei Yee	peiyee@ums.edu.my	60109826559	t	2025-11-07 00:08:39.642005	23	1	1	\N	\N	\N	{"role": "Lecturer", "company": "Universiti Malaysia Sabah", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:17.268333	2025-11-07 00:08:39.642609	peiyee@ums.edu.my	60109826559	associate professor dr chin pei yee	\N
763	def3a6c7-af1e-43ed-9d6d-a4e2b7bd2cd8	1	1	\N	Shirley Hee	shirleyhee@gmail.com	0123456	t	2025-11-07 00:22:09.305868	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG PROPERTIES SDN BHD", "position": "HUMAN RESOURCES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:45.106156	2025-11-12 01:26:15.23504	shirleyhee@gmail.com	0123456	shirley hee	\N
693	a48f0928-2522-454d-a126-7d70acddc5c5	1	1	\N	Josephine Lim	borneo.joproperties@gmail.com	60102608770	t	2025-11-07 00:10:07.763559	29	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "AJ Petromart Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:03:56.807988	2025-11-07 00:10:07.764141	borneo.joproperties@gmail.com	60102608770	josephine lim	\N
714	974a8f60-bae9-42a1-915c-24926e7320ae	1	1	\N	Ellvivi Elysiana Kaimbu	Elysiana.kaimbu@sabah.gov	60189626097	t	2025-11-07 00:08:18.983823	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "KEPKAS", "position": "IT ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:18.983823	2025-11-07 00:08:18.983823	elysiana.kaimbu@sabah.gov	60189626097	ellvivi elysiana kaimbu	\N
715	1d6ec53d-d6d1-4389-9339-633f4d379771	1	1	\N	Fung Siew Nie@anny	account@cocoakingdom.com	60143753437	t	2025-11-07 00:13:27.58188	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KK Chocolate House Sdn Bhd", "position": "Account & Admin Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:38.870281	2025-11-07 00:13:27.582475	account@cocoakingdom.com	60143753437	fung siew nie@anny	\N
716	ede09e3f-db5c-4c0c-9136-a414c86b3ead	1	1	\N	Arunaa	arunaa@ilmulearning.com	60138100274	t	2025-11-07 00:12:11.784567	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ilmu Institute if Learning", "position": "Executive Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:41.547771	2025-11-07 00:12:11.78518	arunaa@ilmulearning.com	60138100274	arunaa	\N
1268	b6475b0b-eb45-4114-b40c-3d001829b15a	1	1	\N	庄燕妮	Jenny@kiankok.edu.my	601161746525	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "建国中学"}	2025-11-08 00:47:02.418438	2025-11-08 00:47:02.418438	jenny@kiankok.edu.my	601161746525	庄燕妮	\N
717	340fbbca-8e3e-48c4-90de-dab1175c3a48	1	1	\N	Ho Fui Cher	judy.ho@bakertilly.com	601135060980	t	2025-11-07 00:10:35.501573	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly LSC Tax Services Sdn Bhd", "position": "Tax Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:09:10.6752	2025-11-07 00:10:35.502244	judy.ho@bakertilly.com	601135060980	ho fui cher	\N
718	ce7bf8c6-0915-4b11-b070-fc2ce7942891	1	1	\N	Kelvin Soimin	Kelvinmarzo@gmail.com	60109309965	t	2025-11-07 00:12:53.583779	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "ILMU INSTITUTE OF LEARNING", "position": "Marketing & Communications", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:09:33.903247	2025-11-07 00:12:53.584509	kelvinmarzo@gmail.com	60109309965	kelvin soimin	\N
735	7b4a4960-41bd-4395-92b2-ee938ad4bdf3	1	1	\N	Juvina Jimis @ Juvinia	Juvina.Jimis@sabah.gov	60128032798	t	2025-11-07 00:13:47.864294	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ministry of Tourism, Culture & Environment", "position": "Administrator officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:13:02.881675	2025-11-07 00:13:47.864787	juvina.jimis@sabah.gov	60128032798	juvina jimis @ juvinia	\N
737	87309c6c-0b87-4ac9-b32c-deb8075ab63a	1	1	\N	Angelina Tan	ajborneohomes@gmail.com	60168528770	t	2025-11-07 00:15:51.512469	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "AJ Petromart SDN BHD", "position": "Admin", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:13:54.543564	2025-11-07 00:15:51.513117	ajborneohomes@gmail.com	60168528770	angelina tan	\N
738	d7b9e87f-a598-4b3d-86e4-97a6dc247d09	1	1	\N	Ellvivi Elysiana Kaimbu	Elysiana.Kaimbu@sabah.gov.my	60189626097	t	2025-11-07 00:15:14.904666	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "KEMENTERIAN PRLANCONGAN KEBUDAYAAN DAN ALAM SEKITAR", "position": "IT OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:13:54.875031	2025-11-07 00:15:14.905382	elysiana.kaimbu@sabah.gov.my	60189626097	ellvivi elysiana kaimbu	\N
751	d450fef5-bc97-4b62-b47d-8a211ef1a574	1	1	\N	Chong Ming Fung	mickey94.aa@gmail.com	60146733571	t	2025-11-07 00:17:35.873648	23	1	1	\N	\N	\N	{"role": "Student", "company": "kkhs", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:17:08.858558	2025-11-07 00:17:35.874407	mickey94.aa@gmail.com	60146733571	chong ming fung	\N
752	3d62421b-f9fe-458f-af7e-81cd931017cf	1	1	\N	Monica Voo Yu Fang	vooyufang94@hotmail.com	60138011457	t	2025-11-07 00:17:54.299539	23	1	1	\N	\N	\N	{"role": "Student", "company": "Kkhs", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:17:11.301263	2025-11-07 00:17:54.300241	vooyufang94@hotmail.com	60138011457	monica voo yu fang	\N
812	a215251d-9c5a-4e16-ad92-6a37fc32b158	1	1	\N	Yapp Ei Yan	Yapp0210@gmail.com	601129926993	t	2025-11-07 02:49:05.179686	23	1	1	\N	\N	\N	{"role": "Student", "company": "Sabah Institute of Art ", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:48:47.292894	2025-11-07 02:49:05.180202	yapp0210@gmail.com	601129926993	yapp ei yan	\N
815	b61d600d-0b3a-4c9d-9914-16036bd1f786	1	1	\N	Elaine Tong	Elainespatisserie@gmail.com	60132633131	t	2025-11-07 02:52:43.491619	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Millie Mallow", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:50:48.328424	2025-11-07 02:52:43.492155	elainespatisserie@gmail.com	60132633131	elaine tong	\N
834	811df66e-0738-4505-a429-246bc48fb174	1	1	\N	Lexin - Salice Lo	salicelo.lexince@gmail.com	60143708665	t	2025-11-07 03:06:42.530871	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lexin Century Enterprise ", "position": "Admin", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:05:55.625439	2025-11-07 03:06:42.531879	salicelo.lexince@gmail.com	60143708665	lexin - salice lo	\N
1293	37fe8344-29aa-4bee-a421-73a531c0f95b	1	3	\N	Carmen Lim	\N	601113180516	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM LIKAS", "position": "Multimedia Designer"}	2025-11-08 01:00:23.547037	2025-11-08 01:00:23.547037	\N	601113180516	carmen lim	\N
652	1dcf30b0-2874-4fae-9700-4582e94e492e	1	1	\N	Muhammad Redzwan Kong Abdullah	redzwanrahimah@gmail.com	601126872373	t	2025-11-06 23:56:48.752229	23	1	1	\N	\N	\N	{"role": "VIP", "company": "AIR WORLD TRAVELLING", "position": "ASSISTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:52:54.475635	2025-11-12 01:20:57.870654	redzwanrahimah@gmail.com	601126872373	muhammad redzwan kong abdullah	\N
1184	6ad0fe80-6496-415c-9e4f-d242db03bbfd	1	1	\N	Rendy M.milin	rendy8344@gmail.com	60168447382	t	2025-11-07 10:19:03.373593	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "ICSB", "position": "OFFICER"}	2025-11-07 10:19:03.373593	2025-11-07 10:19:34.398889	rendy8344@gmail.com	60168447382	rendy m.milin	\N
642	2625a012-b0a0-4a8f-9e60-e27d6d4cc9bd	1	1	\N	Jason Blasius	jasonlkns@gmail.com	60138501579	t	2025-11-06 23:55:31.9345	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah Cultural Board", "position": "HR Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:46:33.126462	2025-11-06 23:55:31.935562	jasonlkns@gmail.com	60138501579	jason blasius	\N
641	34e7ab30-4e28-470b-bf44-6ff5107075cd	1	1	\N	Aswang	aswanamran07@gmail.com	60128640571	t	2025-11-06 23:52:25.58809	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "DRAFTER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:45:55.641636	2025-11-11 23:56:47.594839	aswanamran07@gmail.com	60128640571	aswang	\N
644	69d5da19-bb13-4b92-9a84-0d452936a8f5	1	1	\N	Shidi Dahlan	shidi@smecorp.gov.my	60128697307	t	2025-11-06 23:49:46.53076	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "SME Corp Malaysia ", "position": "Pembantu Eksekutif / Pembantu Khas Pengerusi SME Corp ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:46:53.519945	2025-11-06 23:49:46.531328	shidi@smecorp.gov.my	60128697307	shidi dahlan	\N
646	064a25a8-609c-4b52-be79-287d2bc835ea	1	1	\N	Chong Zheng Hao	chong@sogip.com.my	60178100907	t	2025-11-06 23:50:21.90445	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah Oil & Gas Development Corporation Sdn Bhd", "position": "Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:48:48.513306	2025-11-06 23:50:21.90504	chong@sogip.com.my	60178100907	chong zheng hao	\N
648	17a0caa9-3d5f-4e8c-a2ac-c4147000bebe	1	1	\N	Shyne Chrystee D Madalus	shynemadalus@gmail.com	60198076757	t	2025-11-06 23:59:43.772034	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Coway", "position": "Sales ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:50:28.152408	2025-11-06 23:59:43.772889	shynemadalus@gmail.com	60198076757	shyne chrystee d madalus	\N
649	aec04b09-6970-44af-accc-07394a715a73	1	1	\N	Danny Madalus	dmadalus@gmail.com	60138510020	t	2025-11-06 23:55:54.978319	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Tantadan Ent", "position": "Business owner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:50:42.030774	2025-11-06 23:55:54.979621	dmadalus@gmail.com	60138510020	danny madalus	\N
651	ffdb1ec0-4f56-48b2-bee5-6c86fef30d07	1	1	\N	Stanleyster Polis	stanley.p@amazingborneo.com	60149151013	t	2025-11-06 23:55:17.309149	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Amazing Borneo", "position": "Senior Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:52:19.206523	2025-11-06 23:55:17.309774	stanley.p@amazingborneo.com	60149151013	stanleyster polis	\N
653	e4d498e9-12c2-4074-984b-8658610a65fe	1	1	\N	Vivit Yee	vivit@sogip.com.my	60168273030	t	2025-11-06 23:59:29.449032	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah Oil and Gas Development Corporation Sdn Bhd ", "position": "Senior Manager Finance ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:52:58.688842	2025-11-06 23:59:29.449659	vivit@sogip.com.my	60168273030	vivit yee	\N
657	efee5347-39a9-44c8-a9ff-1e8d49f2d11b	1	1	\N	Rosyati Binti Haji Suni	sunichocolate@gmail.com	60142039895	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "ZABARDAS ENTERPRISE ", "position": "MANAGER ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:54:49.691635	2025-11-06 23:54:49.691635	sunichocolate@gmail.com	60142039895	rosyati binti haji suni	\N
722	bff41779-a4c7-472e-8ccb-44904e1fe97b	1	1	\N	Nur'fazlina	nfazlina111@gmail.com	60146523361	t	2025-11-07 00:11:35.560047	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "AMAZING BORNEO TOURS & EVENTS SDN BHD", "position": "supervisor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:10:37.034603	2025-11-07 00:11:35.56067	nfazlina111@gmail.com	60146523361	nur'fazlina	\N
733	ec49b8ea-28e6-4620-8403-f614701a98c9	1	1	\N	Beautifully John	Beautifullyjohn1@gmail.com	60142814824	t	2025-11-07 00:14:48.216524	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ministry of tourism, culture and environment", "position": "Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:12:54.45927	2025-11-07 00:14:48.217163	beautifullyjohn1@gmail.com	60142814824	beautifully john	\N
643	f6b6e383-9d0d-4fac-90b3-cd1f4d50489b	1	1	\N	Marianih Binti Maidin	Memeyrizky037@gmail.com	601126680321	t	2025-11-06 23:55:14.623315	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "QC", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:46:41.947822	2025-11-11 23:56:36.718156	memeyrizky037@gmail.com	601126680321	marianih binti maidin	\N
744	109d3527-f0c4-419c-a488-1f77dd86cb1e	1	1	\N	Sairah Indan	Ssayindan@gmail.com	60138560800	t	2025-11-07 00:26:17.717248	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sumuni Sdn Bhd  KDCA", "position": "Managing Dirrctor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:15:04.208131	2025-11-07 00:26:17.71778	ssayindan@gmail.com	60138560800	sairah indan	\N
753	6ca1fdc8-a7e9-41a3-9809-0c9649ceff11	1	1	\N	Arnie	jslady2207@gmail.com	60162207902	t	2025-11-07 00:18:03.200214	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "JHEWA", "position": "promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:17:28.008536	2025-11-07 00:18:03.201298	jslady2207@gmail.com	60162207902	arnie	\N
236	ef062956-3172-4dfd-8a6d-5e0e4d2bc850	1	7	\N	Adli Haikal Abdul Hanib	\N	\N	t	2025-11-05 10:21:01.514184	23	1	1	\N	\N	\N	{"role": "VIP", "company": "MATRADE", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:59:16.554419	2025-11-05 10:21:01.51552	\N	\N	adli haikal abdul hanib	\N
246	b3a71a75-b495-4031-89ad-8245ebf2c1ca	1	7	\N	Adolf Anthony Lajinga	\N	\N	t	2025-11-05 10:20:24.940191	23	1	1	\N	\N	\N	{"role": "VIP", "company": "CGC", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:12:18.459509	2025-11-05 10:20:24.941328	\N	\N	adolf anthony lajinga	\N
64	519a3449-11e1-4d10-844e-3a0c7786880e	1	2	\N	Cheah	\N	016-5833333	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ilmu Institute of Learning", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:33:35.248979	2025-11-06 17:43:43.228646	\N	0165833333	cheah	\N
629	551165fc-05e9-41b6-be39-dd7345c07210	1	1	\N	Herni Munir	herni@smecorp.gov.my	60128449901	t	2025-11-06 23:59:41.548269	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "SME Corp. Malaysia(Sabah)", "position": "Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:41:45.927918	2025-11-06 23:59:41.548935	herni@smecorp.gov.my	60128449901	herni munir	\N
630	bf97571f-06b9-4785-bdcb-44c92bfeb1ce	1	1	\N	Koay Li Sher	lisher@hlib.hongleong.com.my	60182368236	t	2025-11-06 23:51:36.389849	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Hong Leong Investment Bank", "position": "Head of Sabah Region", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:41:50.60116	2025-11-07 00:10:54.39598	lisher@hlib.hongleong.com.my	60182368236	koay li sher	\N
655	74f699d8-eb4f-4a12-98f9-6e1e50a0cbd1	1	1	\N	Rosli Shirlin	rosli@sogip.com.my	60168203003	t	2025-11-06 23:59:13.986143	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah Oil & Gas Development Corporation", "position": "HR & Admin Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:54:09.595108	2025-11-06 23:59:13.986835	rosli@sogip.com.my	60168203003	rosli shirlin	\N
723	1c400ad7-f945-4729-91e0-96787cf62543	1	1	\N	Norkiah Mansaab @maasaat	norkiahmansaab@gmail.com	60128204833	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "kia trading", "position": "exibitior", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:10:57.533893	2025-11-07 00:10:57.533893	norkiahmansaab@gmail.com	60128204833	norkiah mansaab @maasaat	\N
90	750ddcf3-516a-4946-8cba-87d0798d417e	1	1	\N	Nicholas Khoo Leong San	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Saradise BDC", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 09:29:20.092837	2025-11-01 09:29:20.092837	\N	\N	nicholas khoo leong san	\N
91	d254607e-2464-41a9-852c-1ba9f1ef83d3	1	1	\N	Edwin Ng	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VVIP", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 09:29:52.82172	2025-11-01 09:29:52.82172	\N	\N	edwin ng	\N
102	cdd65e2e-3bee-4669-a2f8-af796e48829f	1	4	\N	Nurin Farzana Tersan Abdullah	\N	60128536926	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Torr Energy Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "Oil & Gas", "print_exhibitor_tag": ""}	2025-11-02 04:10:27.526246	2025-11-02 04:10:27.526246	\N	\N	nurin farzana tersan abdullah	\N
726	7be0a4f3-9d75-452c-97ee-8b7c8e2e50fe	1	1	\N	Jane Cassandra	sj_jane73@yahoo.com	60102719098	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Oil & Gas Dev. Corp. SB", "position": "Legal Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:19.885235	2025-11-07 00:11:19.885235	sj_jane73@yahoo.com	60102719098	jane cassandra	\N
736	f51a9b37-ec14-4a36-a936-ebbf5dbcd4bf	1	1	\N	Benny Ng Su Pei	bennynsp@gmail.com	60168100005	t	2025-11-07 00:15:09.039044	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Glowbest Sdn Bhd", "position": "Managing Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:13:22.569062	2025-11-07 00:15:09.039949	bennynsp@gmail.com	60168100005	benny ng su pei	\N
175	4fc44362-a2c7-4f87-8321-fafd3d20f30f	1	1	\N	KUE SIEW CHIN	\N	0162398919	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Evopoint Sdn Bhd", "position": "Business Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:43:06.345526	2025-11-03 07:43:06.345526	\N	\N	kue siew chin	\N
208	fdb264e4-5fe0-4271-9dd7-22876eff166f	1	3	\N	Jeff Yeap	\N	0193707777	t	2025-11-07 08:57:16.182202	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "RESTU MART SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:40:42.787244	2025-11-07 08:57:16.182893	\N	0193707777	jeff yeap	\N
262	8b47bf3f-2fcf-44cf-af38-a2d098f4f0bb	1	7	\N	Yogo Pamungkas Ms	\N	\N	t	2025-11-05 09:51:26.711137	23	1	1	\N	\N	\N	{"role": "VIP", "company": "CONSULATE GENERAL REPUBLIC OF INDONESIA ", "position": "CONSUL", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:59:34.259031	2025-11-05 09:51:26.712006	\N	\N	yogo pamungkas ms	\N
231	f9917ce4-48ee-45cb-af8c-cb1245baaf32	1	7	\N	Ingrid Edy	\N	\N	t	2025-11-05 10:14:40.28637	23	1	1	\N	\N	\N	{"role": "VIP", "company": "MPC", "position": "ASSISTANT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:44:26.072514	2025-11-05 10:14:40.287237	\N	\N	ingrid edy	\N
232	3c68908d-667e-446b-bca7-72f90ec4870b	1	7	\N	Ts. Hazrullizam Bin Idris	\N	\N	t	2025-11-05 09:56:46.013243	23	1	1	\N	\N	\N	{"role": "VIP", "company": "HRDF", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:45:12.160783	2025-11-05 09:56:46.013852	\N	\N	ts. hazrullizam bin idris	\N
234	92eb7d97-cb75-4091-aca6-a3fbd3eedb7b	1	7	\N	Valentine Thomas	\N	\N	t	2025-11-05 09:56:04.945798	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SME CORPORATION MALAYSIA ", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:57:44.568261	2025-11-05 09:56:04.946545	\N	\N	valentine thomas	\N
235	1630c19a-0bf4-4c53-a18b-c7dec77a5331	1	7	\N	Mischellyn Masuning	\N	\N	t	2025-11-05 10:05:27.663138	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SME CORPORATION MALAYSIA ", "position": "ASSISTANT STATE DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:58:33.462401	2025-11-05 10:05:27.663736	\N	\N	mischellyn masuning	\N
239	704647d0-bdb8-47c3-9e7c-486bc781cdc1	1	7	\N	Mohammad Fairol Lai	\N	\N	t	2025-11-05 10:04:28.889691	23	1	1	\N	\N	\N	{"role": "VIP", "company": "MIDA", "position": "ASSISTANT DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:03:17.958797	2025-11-05 10:04:28.890313	\N	\N	mohammad fairol lai	\N
240	d0a38b37-ba6a-43c7-ae36-7f4f69f636d8	1	7	\N	Sudirman Mohd Alwi	\N	\N	t	2025-11-05 11:46:58.830386	25	1	1	\N	\N	\N	{"role": "VIP", "company": "MIDF", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:04:33.658058	2025-11-05 11:46:58.831076	\N	\N	sudirman mohd alwi	\N
242	cdd20a65-9a9c-4159-a9b6-97868d3bc712	1	7	\N	Chin Kah Yi	\N	\N	t	2025-11-05 10:18:51.274338	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH NET", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:09:33.788817	2025-11-05 10:18:51.275017	\N	\N	chin kah yi	\N
244	aa61450d-ed14-466d-a121-a5eaee686a22	1	7	\N	Siti Nur'ain Abdullah	\N	\N	t	2025-11-05 09:57:39.650889	23	1	1	\N	\N	\N	{"role": "VIP", "company": "DIDR", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:11:07.664808	2025-11-05 09:57:39.651899	\N	\N	siti nur'ain abdullah	\N
247	38b8d850-153f-47f6-94b6-dbf5313eb481	1	7	\N	Dr Firdausi Suffian	\N	\N	t	2025-11-05 10:17:05.954837	23	1	1	\N	\N	\N	{"role": "VIP", "company": "INVEST SABAH BERHAD", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:28:10.391377	2025-11-05 10:17:05.955597	\N	\N	dr firdausi suffian	\N
249	bb41769f-6525-4a83-b4ec-1d8fbbf9cc2a	1	7	\N	Kristo Henry Williams	\N	\N	t	2025-11-05 10:07:03.457791	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH FORESTRY DEPT ", "position": "PLANNING OFFICER ON INTERNATIONAL AFFAIRS AND CORPORATE COLLABORATION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:33:25.340001	2025-11-05 10:07:03.458714	\N	\N	kristo henry williams	\N
1186	242e3ff6-ad5b-4ddc-a64e-170c2b23877b	1	1	\N	Lynette Wong	yongvt@gmail.com	60168259399	t	2025-11-07 10:23:12.449537	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Dmm perodua", "position": "Sales advisor"}	2025-11-07 10:23:12.449537	2025-11-07 10:23:12.449537	yongvt@gmail.com	60168259399	lynette wong	\N
251	2174457e-1ed8-409b-8127-363316c64423	1	7	\N	Bonny Lin	\N	\N	t	2025-11-05 10:19:17.238441	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH CONVENTION BUREAU", "position": "MARCOMM EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 11:36:19.85304	2025-11-05 10:19:17.239393	\N	\N	bonny lin	\N
254	e313fa73-1e16-4f5f-87d8-f5224e627723	1	7	\N	Datuk Ramlee Bin Kariah	\N	\N	t	2025-11-05 10:17:36.915636	23	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH MAJU JAYA SEKRETARIAT ", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:05:05.159856	2025-11-05 10:17:36.916283	\N	\N	datuk ramlee bin kariah	\N
256	d8c7d9b0-89c1-40a5-aa95-3f4a7765deb1	1	7	\N	Rudy Jaglul	\N	\N	t	2025-11-05 09:59:37.975669	23	1	1	\N	\N	\N	{"role": "VIP", "company": "QHAZANAH SABAH BERHAD", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:08:20.171539	2025-11-05 09:59:37.976493	\N	\N	rudy jaglul	\N
258	88465122-0641-4af9-ac17-4f3703b06c41	1	7	\N	Prof Ts Dr Mohd Hanafi	\N	\N	t	2025-11-05 10:02:06.732778	23	1	1	\N	\N	\N	{"role": "VIP", "company": "UMS", "position": "DEKAN FAKULTI KOMPUTERAN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:11:03.478557	2025-11-05 11:09:32.078831	\N	\N	prof ts dr mohd hanafi	\N
260	40b70795-5a8d-4bfa-a8b1-b12f1330b41a	1	7	\N	Md Redzuan Rahman	\N	\N	t	2025-11-05 10:06:17.820286	23	1	1	\N	\N	\N	{"role": "VIP", "company": "TERAJU, SABAH", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 13:55:04.747593	2025-11-05 10:06:17.820972	\N	\N	md redzuan rahman	\N
266	71af0b16-a627-42de-8bc7-15b4c9b8dab0	1	7	\N	Associate Professor Ts Dr Chin Pei Yee	\N	\N	t	2025-11-06 01:32:41.06853	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "UMS INDUSTRY & COMMUNITY NETWORK", "position": "DEPUTY DIRECTOR, CENTRE FOR INDUSTRIAL COLLABORATION AND ENGAGEMENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 14:10:06.168488	2025-11-06 01:32:41.069336	\N	\N	associate professor ts dr chin pei yee	\N
632	0ca0041e-273b-4a3c-b502-c9a1cdcb579e	1	1	\N	Syarliza Yunus	azilrays@gmail.com	60168844174	t	2025-11-06 23:53:04.619871	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "PURCHASING OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:42:57.224898	2025-11-06 23:53:04.620962	azilrays@gmail.com	60168844174	syarliza yunus	\N
640	ff9d38c2-1418-4030-979f-ae990708b8b6	1	1	\N	Connie Ramy	mulan_coni@yahoo.com.my	60178383384	t	2025-11-06 23:55:04.107672	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "LEMBAGA KEBUDAYAAN  NEGERI SABAH", "position": "PEMBANTU TADBIR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:44:35.840688	2025-11-06 23:55:04.10845	mulan_coni@yahoo.com.my	60178383384	connie ramy	\N
951	30d130df-3d61-4a0e-921e-f53702ad3a7f	1	1	\N	Jalina Binti Jahari	yulybrands@yahoo.com	601119583166	t	2025-11-07 05:23:03.607681	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "YULY GLOBAL INTERNATIONAL SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:22:32.318663	2025-11-07 05:23:03.612323	yulybrands@yahoo.com	601119583166	jalina binti jahari	\N
196	6c0e0bcf-d3c4-4968-8df2-ac83bd8b8af1	1	3	\N	Lesu Hen Ri	\N	01115099818	t	2025-11-07 08:57:30.021121	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "Student", "coupon_referral": "", "business_industry": "Education", "print_exhibitor_tag": ""}	2025-11-03 08:19:55.649551	2025-11-07 08:57:30.021826	\N	01115099818	lesu hen ri	\N
20	326a687d-ef9d-4077-ad40-2cad288bebc5	1	1	\N	Suhailah Zabri	\N	012-9393483	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLElogy Development", "position": "Project Exec", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:53:02.481137	2025-11-06 02:23:46.363067	\N	0129393483	suhailah zabri	\N
29	687999a0-c81f-4eef-a05b-7f57307f6e76	1	1	\N	Jackie	\N	012-8331130	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "C&F Enterprise Sdn Bhd", "position": "Director of Marketing", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 04:14:05.37341	2025-11-01 09:32:20.385286	\N	0128331130	jackie	\N
639	9245d08a-b05d-4e49-af9f-d8333fe9c047	1	1	\N	Nor Fatihah Rozarina Roslee	Rozarinaf@gmail.com	60128501810	t	2025-11-06 23:55:33.203526	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "ASST SUPERVISOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:44:34.388287	2025-11-11 23:58:20.72517	rozarinaf@gmail.com	60128501810	nor fatihah rozarina roslee	\N
638	28b42d63-3b2f-43b0-b321-87c53a51c9c8	1	1	\N	Fiffy	sshazne17@gmail.com	601121556543	t	2025-11-06 23:53:46.847571	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "SALES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:44:26.230888	2025-11-11 23:58:28.27776	sshazne17@gmail.com	601121556543	fiffy	\N
170	405fe462-8cb4-4df0-ba66-48fa0dae8162	1	1	\N	Elsie Maria Marcus	\N	0138024331	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "ASSISTANT DIGITAL AND COMMUNICATION MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:33:42.089529	2025-11-12 00:51:10.143563	\N	0138024331	elsie maria marcus	\N
1187	1828d3b5-491d-42bf-a271-f50abfcdb2c3	1	1	\N	Zack Liew	zackliew26@gmail.com	60194281281	t	2025-11-07 10:27:21.597454	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Zltf management ", "position": "Consultant "}	2025-11-07 10:27:21.597454	2025-11-07 10:27:21.597454	zackliew26@gmail.com	60194281281	zack liew	\N
72	6f0fea53-1a01-4940-9edf-9b660371ee0d	1	2	\N	Jessica Amat	\N	011-16031811	t	2025-11-07 00:34:58.101318	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Sunduan Preloved Items", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:48:34.48419	2025-11-07 00:34:58.102199	\N	01116031811	jessica amat	\N
34	ea8587f8-3e64-4321-a3fc-9e9c418a0bfb	1	2	\N	Marion Megan Nicholas	\N	012-8164428	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Jackhan Furniture Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:02:25.436386	2025-11-06 17:43:47.284823	\N	0128164428	marion megan nicholas	\N
100	5a191043-55cd-4080-85db-7e8828c05ea7	1	3	\N	陈道威	\N	0128106850	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "", "position": "Engineering", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 10:38:48.70477	2025-11-01 10:38:48.70477	\N	0128106850	陈道威	\N
143	8bf6f6e6-b71c-4ca0-b9b5-a69c39e7a588	1	1	\N	LING FUI KIONG	\N	0128296161	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "UNIANG PLASTIC INDUSTRIES SDN BHD", "position": "ACCOUNTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:56:18.256112	2025-11-03 06:56:18.256112	\N	0128296161	ling fui kiong	\N
144	786d7ac5-ed5f-419c-8bbe-0c92e650d2da	1	1	\N	Mimi Marisya	\N	012-5991740	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLElogy", "position": "Lead Development Partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:57:00.231865	2025-11-06 02:23:46.416952	\N	0125991740	mimi marisya	\N
147	19d2ba69-8882-433c-a449-9ae5c0c8a9e5	1	1	\N	DAVID LEE	\N	0128863609	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "JAYA UNIANG SDN BHD", "position": "SALES MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:59:17.253032	2025-11-03 06:59:17.253032	\N	0128863609	david lee	\N
164	c73162c1-b536-4d67-9195-bf1b30ac8b63	1	1	\N	Siti Mahsuri Dicky	\N	01115777518	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Mahsuri & Co", "position": "Sole Proprietor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:24:33.184997	2025-11-03 07:24:33.184997	\N	01115777518	siti mahsuri dicky	\N
192	ff5117a6-1f19-4866-86f5-e42f01daf34c	1	3	\N	Yeong Kok Wah	\N	0128290380	t	2025-11-07 08:58:02.754035	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ky Trading", "position": "MB", "coupon_referral": "", "business_industry": "F & B", "print_exhibitor_tag": ""}	2025-11-03 08:14:25.640453	2025-11-07 08:58:02.755065	\N	0128290380	yeong kok wah	\N
204	f4f7842c-c7b7-4d38-ba91-1e70c93e916c	1	3	\N	Hannah Isabelle	\N	0128291833	t	2025-11-07 08:58:09.924499	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Tshung Tsin Secondary School", "position": "Student", "coupon_referral": "", "business_industry": "Student", "print_exhibitor_tag": ""}	2025-11-03 08:32:51.174143	2025-11-07 08:58:09.925155	\N	0128291833	hannah isabelle	\N
62	cb2ba3fa-4406-43a1-9948-26d0fc3f475b	1	2	\N	Isabel Lo	\N	012-378 8930	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Urban Homefarming - healthy foods platform", "position": "", "coupon_referral": "", "business_industry": "(F&B)", "print_exhibitor_tag": ""}	2025-10-31 07:31:25.250963	2025-11-06 17:39:42.318666	\N	0123788930	isabel lo	\N
637	6c249e04-c173-4449-8799-6c2eabe5ef4a	1	1	\N	Hartikavia Mojilip	hartikamojilip@gmail.com	60178330809	t	2025-11-06 23:54:08.360579	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "HR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:44:18.842617	2025-11-06 23:54:08.361279	hartikamojilip@gmail.com	60178330809	hartikavia mojilip	\N
73	41147c47-2179-4ded-bac0-bbae91c6802d	1	2	\N	Hanifah Kinsu	\N	013-6333231	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Huminodun Collections", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:13:46.059607	2025-11-06 17:43:58.752557	\N	0136333231	hanifah kinsu	\N
818	28025ba8-7450-41b7-80c5-c5498db13e54	1	1	\N	Richard J Munang	rjm.borneo@gmail.com	60109309873	t	2025-11-07 02:57:58.866747	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "RJM ", "position": "Entrepreneur", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:55:28.43829	2025-11-07 02:57:58.86737	rjm.borneo@gmail.com	60109309873	richard j munang	\N
190	3b19b3e1-4ad1-4d17-81b3-449d47ad4602	1	3	\N	Lau Yan Tung	\N	01126191273	t	2025-11-07 08:57:56.435314	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School ", "position": "Student", "coupon_referral": "", "business_industry": "Education", "print_exhibitor_tag": ""}	2025-11-03 08:12:14.660629	2025-11-07 08:57:56.435943	\N	01126191273	lau yan tung	\N
7	579e1990-a101-4f03-a7fd-bf771426cfa2	1	1	\N	Sia Mee Kuong	\N	016-8320036	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Uni Lumber Sdn Bhd", "position": "Committee Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:43:30.791235	2025-11-01 09:40:19.996191	\N	0168320036	sia mee kuong	\N
17	7368800a-5467-4148-ba0a-705c321acf6b	1	1	\N	Benny Ng Su Pei	\N	016-8100005	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Glowbest Sdn Bhd", "position": "Managing Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:50:07.810434	2025-11-01 09:53:48.094745	\N	0168100005	benny ng su pei	\N
65	8eaf3acc-a52f-43ec-9a6d-13a1357b1d02	1	2	\N	Stephen Siaw	\N	016-8313163	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lilith Bakery -  Gluten free baked goods", "position": "", "coupon_referral": "", "business_industry": "(F&B)", "print_exhibitor_tag": ""}	2025-10-31 07:40:13.199888	2025-11-06 17:40:17.716506	\N	0168313163	stephen siaw	\N
37	85c40cbd-c033-46f1-b473-f3a2164e0c94	1	2	\N	Tony Chew	\N	016-5394731	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "ADSMART MARKETING", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:06:34.014636	2025-11-12 00:10:51.789168	\N	0165394731	tony chew	\N
96	674d5a80-d6e9-4a06-a86e-c9159eacd8c0	1	3	\N	Micheal Kiu	\N	0167035967	t	2025-11-07 08:58:38.902135	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property ", "position": "Property Agent", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 10:13:33.546624	2025-11-07 08:58:38.902769	\N	0167035967	micheal kiu	\N
645	f0e5e6f7-6cf0-44f6-a89f-8d8748fdc0e6	1	1	\N	Frederick Chung	Chung.tze.vui@kkip.com.my	60168370915	t	2025-11-06 23:49:13.334512	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "KKIP SDN BHD", "position": "INTERNAL AUDIT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:47:06.549113	2025-11-12 00:31:12.504428	chung.tze.vui@kkip.com.my	60168370915	frederick chung	\N
60	001eb7ce-9e79-4966-a68e-a5b4b6c18c58	1	2	\N	Felix Liewhan	\N	014 6584569	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Insfire Studio", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:30:18.202718	2025-11-06 17:44:08.379484	\N	0146584569	felix liewhan	\N
188	7c4c5895-33c5-4a31-bacc-dbbf35e1ed9a	1	3	\N	Chong Cha Chye	\N	0168226721	t	2025-11-07 08:58:45.899057	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "Student", "coupon_referral": "", "business_industry": "Education", "print_exhibitor_tag": ""}	2025-11-03 08:05:45.405406	2025-11-07 08:58:45.899771	\N	0168226721	chong cha chye	\N
133	30702e12-7218-4a62-9479-c54eeb778471	1	1	\N	NOUVA @ NELLY SUIKING	\N	014-9988410	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "SENIOR SALES & MARKETING EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:37:00.48556	2025-11-03 06:37:00.48556	\N	0149988410	nouva @ nelly suiking	\N
137	aefa0a63-152b-4508-9bca-4b4af75a5005	1	1	\N	Stanley Ong	\N	016-8328587	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Uniang Plastic Industries Sdn. Bhd.", "position": "IT EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:49:50.536196	2025-11-03 06:49:50.536196	\N	0168328587	stanley ong	\N
138	153b0b85-7969-4a8b-9f19-1f92b2efff8e	1	1	\N	HUANG LEN LEN	\N	0138661122	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "KIMANIS FOOD INDUSTRIES SDN BHD", "position": "GENERAL MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:50:51.704159	2025-11-03 06:50:51.704159	\N	0138661122	huang len len	\N
140	d5f1eace-7229-41ec-8291-be86d1f7f2fc	1	1	\N	Penny Sin	\N	0165093086	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Kimanis Food Industries Sdn Bhd", "position": "Ass.Operation Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:53:31.865857	2025-11-06 02:23:46.402179	\N	0165093086	penny sin	\N
146	c203fb80-662e-400f-bdf6-e9be0ed595a6	1	1	\N	Lim Fang Boon	\N	016-8312896	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lok Kawi Plastic Industries Sdn Bhd", "position": "Operation Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:58:41.060083	2025-11-03 06:58:41.060083	\N	0168312896	lim fang boon	\N
152	7956de1a-468c-4901-a9ae-bb94a1be4f7b	1	1	\N	Muhamad Suhairi Bin Mohd Ariffin	\N	0139961815	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Evopoint Sdn. Bhd.", "position": "Business Application Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:05:09.087126	2025-11-06 02:23:46.450316	\N	0139961815	muhamad suhairi bin mohd ariffin	\N
163	e65808a2-2efb-4f0b-80ee-a331de8f061c	1	1	\N	Laura Miatong	\N	0138832378	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Invest Sabah Bhd", "position": "Senior Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:23:25.303054	2025-11-03 07:23:25.303054	\N	0138832378	laura miatong	\N
729	230ba774-bca3-4462-8ae8-fc8676692585	1	1	\N	Linus Joseph	joseph_linus@yahoo.co.uk	60148147236	t	2025-11-07 00:14:21.078798	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah Skills & Technology Center ", "position": "Trainer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:41.426983	2025-11-07 00:14:21.079525	joseph_linus@yahoo.co.uk	60148147236	linus joseph	\N
49	eb8d6bb3-43ae-45d9-9925-235c74c9f35d	1	2	\N	Eric Yong	\N	014-6705887	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Sun Bear Tours & Travels Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:21:45.354643	2025-11-06 17:39:57.228292	\N	0146705887	eric yong	\N
731	c7c12922-8675-4bc2-96cc-effb1111c580	1	1	\N	Rohana Teo	nanateo01@gmail.com	60178337313	t	2025-11-07 00:13:27.283831	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Researcher", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:12:02.058796	2025-11-07 00:13:27.284568	nanateo01@gmail.com	60178337313	rohana teo	\N
819	09b3d1f7-bcdc-4264-9ec5-ea0aa79f1598	1	1	\N	Afendey Jinir	afendeyjinir@amccollege.edu.my	60178961334	t	2025-11-07 02:56:42.867156	23	1	1	\N	\N	\N	{"role": "Lecturer", "company": "AMC UNIVERSITY COLLEGE", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:55:49.352019	2025-11-07 02:56:42.867823	afendeyjinir@amccollege.edu.my	60178961334	afendey jinir	\N
835	4ffed150-96b6-43b9-b6f1-97a723c06954	1	1	\N	Rashidi Murshid	yulychaca@gmail.com	601117800726	t	2025-11-07 03:07:21.431004	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "yuly global international sdn bhd", "position": "EXPORT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:06:20.862077	2025-11-07 03:07:21.431532	yulychaca@gmail.com	601117800726	rashidi murshid	\N
98	b9622187-0101-4647-aa88-8b324d4b4522	1	3	\N	Renee	\N	0168108237	t	2025-11-07 08:58:15.090663	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "CT Toys Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-01 10:23:48.378986	2025-11-07 08:58:15.091259	\N	0168108237	renee	\N
6	ff79f41a-3189-4d94-93b2-a65f731050e1	1	1	\N	Lee Lye Soon	\N	019-8604899	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Excella Wood Industries Sdn Bhd", "position": "Committee Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:42:48.119184	2025-11-01 09:39:48.032247	\N	0198604899	lee lye soon	\N
12	3210450b-4434-4bb9-878b-b34ff989c472	1	1	\N	Chin Shaw Fung	\N	017-8398670	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Enagic Co., TrueHealth9.5 International", "position": "Group Leader", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:47:46.221817	2025-11-01 09:48:35.796557	\N	0178398670	chin shaw fung	\N
633	799e0d35-688e-4e6c-b8cc-9a4c40580eda	1	1	\N	Zulkarnain Bin Mohd Isa	zulkarnainmohdisa@gmail.com	60168221385	t	2025-11-06 23:52:03.139057	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN.BHD ", "position": "OFFICE ASST", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:43:07.517888	2025-11-06 23:52:03.139809	zulkarnainmohdisa@gmail.com	60168221385	zulkarnain bin mohd isa	\N
636	b8148fd8-03c6-4a9a-a25f-ab942605ce05	1	1	\N	Mohd Nazrin Shah Bin Nasip	MohdNazrin.Nasip@sabah.gov.my	60149575022	t	2025-11-06 23:53:53.42182	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Lembaga Kebudayaan Negeri Sabah ", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:44:14.792707	2025-11-06 23:53:53.42268	mohdnazrin.nasip@sabah.gov.my	60149575022	mohd nazrin shah bin nasip	\N
1189	4fd95dc6-c32c-4ad7-9901-2b70bcf9c266	1	1	\N	Moo Ket Weng	Kketweng@gmail.com	60147048328	t	2025-11-07 10:27:48.082396	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Dynasty water sdn bhd", "position": "Operation manager"}	2025-11-07 10:27:48.082396	2025-11-07 10:27:48.082396	kketweng@gmail.com	60147048328	moo ket weng	\N
77	d05985bc-7ea6-4d63-868c-3f8c8655eae4	1	2	\N	James Ha Haw Yew	\N	019-8528324	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Dong Sin Food Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:34:14.395978	2025-11-06 17:39:13.817139	\N	0198528324	james ha haw yew	\N
44	051df603-b9c8-41b7-bdfd-818d0bd7dad5	1	2	\N	Chiew Lerk Chen	\N	017-785 2220	t	2025-11-07 00:24:50.615711	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cygnus Technology Solutions Sdn. Bhd.", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:18:14.249084	2025-11-07 00:24:50.616337	\N	0177852220	chiew lerk chen	\N
106	bdfcb479-4874-4655-b386-31cf32a381a8	1	4	\N	Florie Catherina I. Makajil	\N	60138800538	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Tangkob Enterprise", "position": "", "coupon_referral": "", "business_industry": "Insurance", "print_exhibitor_tag": ""}	2025-11-02 04:12:48.218764	2025-11-02 04:12:48.218764	\N	60138800538	florie catherina i. makajil	\N
131	e0ea0d72-e17a-413e-b3b8-1e219adcdda4	1	1	\N	YAP KAH MENG	\N	016-8478001	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SRI KOMPUTER SDN BHD", "position": "OPERATIONS MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:06:10.612004	2025-11-03 06:06:10.612004	\N	0168478001	yap kah meng	\N
141	dc8d170a-d01e-4545-b7b5-2d9eac6a3b94	1	1	\N	CELIA HO	\N	0168463060	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "JAYA UNI'ANG SB", "position": "ACCOUNTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:54:38.462881	2025-11-03 06:54:38.462881	\N	0168463060	celia ho	\N
148	d6bc0d8f-e386-4c69-8fb6-488c5c606c6b	1	1	\N	KADHIRESHAAN A/L BALAKRISHNAN	\N	0173042774	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLElogy Development Sdn Bhd", "position": "Project Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:00:08.73001	2025-11-03 07:00:08.73001	\N	0173042774	kadhireshaan a/l balakrishnan	\N
150	395491e7-4a2d-4200-95b7-e0dd927cc841	1	1	\N	Loo Xin Lin	\N	0187916165	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Evopoint Sdn Bhd", "position": "Business Application Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:02:36.773284	2025-11-03 07:02:36.773284	\N	0187916165	loo xin lin	\N
200	95479ba6-7f6c-4a5b-92e8-af435176edb4	1	3	\N	Jessie James Ngu Yen	\N	0178061627	t	2025-11-07 08:59:10.091436	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Tshung Tsin Secondary School", "position": "Student", "coupon_referral": "", "business_industry": "Student", "print_exhibitor_tag": ""}	2025-11-03 08:29:36.861309	2025-11-07 08:59:10.092064	\N	0178061627	jessie james ngu yen	\N
203	fee2bb52-47d0-485b-b113-4fe1b3c2a623	1	3	\N	Aaron Chu	\N	0178202788	t	2025-11-07 08:59:23.141418	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": "Real Estate Agent", "coupon_referral": "", "business_industry": "Real Estate Services", "print_exhibitor_tag": ""}	2025-11-03 08:32:02.279736	2025-11-07 08:59:23.142045	\N	0178202788	aaron chu	\N
69	28dd5447-ec94-4428-99a3-89c00756dbc4	1	2	\N	Nurul Firdah Binti Noordin	\N	017-4755282	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Qyra Anugera", "position": "", "coupon_referral": "", "business_industry": "F&B", "print_exhibitor_tag": ""}	2025-10-31 07:43:56.449672	2025-11-06 17:39:05.738719	\N	0174755282	nurul firdah binti noordin	\N
66	9038f347-a812-46a9-95e1-fba18d2fb1f1	1	2	\N	Mable Wong Hui Qi	\N	016-833 9342	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Phileo Gelato", "position": "", "coupon_referral": "", "business_industry": "F&B", "print_exhibitor_tag": ""}	2025-10-31 07:40:56.148837	2025-11-06 17:22:31.74797	\N	0168339342	mable wong hui qi	\N
70	53851eda-d177-45b7-8b74-d12ea1fa29e9	1	2	\N	Chin Shih Looi	\N	016-8396780	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lido Xiang Xiang Squid", "position": "", "coupon_referral": "", "business_industry": "F&B", "print_exhibitor_tag": ""}	2025-10-31 07:44:56.070839	2025-11-06 17:22:27.417242	\N	0168396780	chin shih looi	\N
647	3da30909-90ac-49b3-8d0f-d9a952b3ebdc	1	1	\N	Joey	Joeylee@peoplelogy.com	60127201814	t	2025-11-06 23:54:07.4063	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Peoplelogy", "position": "Coo", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:50:14.950396	2025-11-06 23:54:07.407066	joeylee@peoplelogy.com	60127201814	joey	\N
654	b8bdf055-2b2f-4a0f-83e0-190795d51b90	1	1	\N	Laila Binti Tahir	sassy_gurls86@yahoo.com	60127861803	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Sabah cultural board", "position": "Pegawai kebudayaan", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:53:54.639846	2025-11-06 23:53:54.639846	sassy_gurls86@yahoo.com	60127861803	laila binti tahir	\N
848	3c631cfc-a09d-4cde-bff4-8812acd2213b	1	1	\N	Rahma	rahma@btc.com	60109410604	t	2025-11-07 03:23:25.742494	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Btc Maju Holding Sdn Bhd", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:13:30.976525	2025-11-07 03:23:25.743098	rahma@btc.com	60109410604	rahma	\N
1004	17ee8605-948b-4f3d-b7fc-620fecc425a0	1	1	\N	Amyra Natasha	johaneamyra@gmail.com	60168234045	t	2025-11-07 06:30:48.455797	29	1	1	\N	\N	\N	{"role": "Student", "company": "UITM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:30:22.550949	2025-11-07 06:30:48.456794	johaneamyra@gmail.com	60168234045	amyra natasha	\N
18	4386f0b0-a995-4878-85eb-4c40a00e5f41	1	1	\N	Yusrina Maliyana Binti Kahar	\N	019-9422159	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "PEOPLELOGY BERHAD", "position": "Project Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-30 03:50:27.195237	2025-11-06 02:23:46.342543	\N	0199422159	yusrina maliyana binti kahar	\N
101	904ff767-f8cf-43ba-887f-434dc8f7bf70	1	4	\N	Nurin Farzana Tersan Abdullah	\N	60128536926	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Torr Energy Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "Oil & Gas", "print_exhibitor_tag": ""}	2025-11-02 04:09:47.21009	2025-11-02 04:09:47.21009	\N	60128536926	nurin farzana tersan abdullah	\N
104	192fd203-94fa-47f5-b81a-c6d258bcf5f4	1	4	\N	Junid bin Zaidi	\N	60128876925	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Torr Energy Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "Oil & Gas", "print_exhibitor_tag": ""}	2025-11-02 04:11:36.637616	2025-11-02 04:11:36.637616	\N	60128876925	junid bin zaidi	\N
135	96ebb9ee-87bc-412a-ba6f-50b1a5605718	1	1	\N	LIEW MING KEONG	\N	019-8808727	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "TWO THOUSAND AND ONE COMPUTER (M) SDN BHD", "position": "CHIEF OPERATING OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:43:58.993641	2025-11-03 06:43:58.993641	\N	0198808727	liew ming keong	\N
122	0d5435f6-5151-4e37-a3b8-cc69385adb1d	1	1	\N	Henry Wong	A@z.com	60138375588	f	\N	\N	0	1	\N	\N	\N	{"role": "student", "company": "UMS", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 03:11:29.883994	2025-11-03 03:11:29.883994	a@z.com	60138375588	henry wong	\N
124	b5a8a1ad-1593-47a1-ae93-547dff1fac1c	1	1	\N	Dan	San@cms.com	60128283537	f	\N	\N	0	1	\N	\N	\N	{"role": "student", "company": "Aus", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 04:24:05.375527	2025-11-03 04:24:05.375527	san@cms.com	\N	dan	\N
134	450553a9-93f0-4f09-9f71-796d68fe9cff	1	1	\N	Hiew Chee Fah @ Khoo Kim Yong	\N	019-8802001	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "TWO THOUSAND AND ONE COMPUTER (M) SDN BHD", "position": "CHIEF EXECUTIVE OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:42:09.254946	2025-11-06 02:23:46.384846	\N	0198802001	hiew chee fah @ khoo kim yong	\N
167	8b24d463-79a0-4ad9-9400-ad74ad91eaa4	1	1	\N	Rachael Tham	\N	60138561088	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "CORPORATE SERVICES MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:27:18.128524	2025-11-06 02:23:46.496422	\N	60138561088	rachael tham	\N
108	18f768d1-2db0-4d84-93b6-3c246745cfa8	1	4	\N	Lee Chai Hoon	\N	60124727693	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BORNEO ECO TOUR SDN BHD", "position": "", "coupon_referral": "", "business_industry": "Tourism", "print_exhibitor_tag": ""}	2025-11-02 04:14:43.94411	2025-11-12 01:04:49.845102	\N	60124727693	lee chai hoon	\N
151	52c64576-c617-4c80-a638-ce386223ea3f	1	1	\N	Izzat Nasri	\N	601112936923	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Evopoint Sdn Bud", "position": "Software Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:03:11.039845	2025-11-06 02:23:46.440676	\N	601112936923	izzat nasri	\N
153	1d91bea5-48c7-4078-824f-14c2fca32f36	1	1	\N	Jeffrey Leong	\N	60126454973	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Verdant Solar Sdn Bhd", "position": "Northern Area Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:07:25.995308	2025-11-03 07:07:25.995308	\N	60126454973	jeffrey leong	\N
193	45281319-0188-453a-8591-bcb52a244e2b	1	1	\N	Danny	dann@hot.com	60128283537	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:16:00.891894	2025-11-03 08:16:00.891894	dann@hot.com	\N	danny	\N
661	a027ff90-2581-483b-953f-17796a5b8e67	1	1	\N	Siti Fatimah	sitifatimah@sabahtourism.com	60138603937	t	2025-11-07 00:00:15.432908	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "ASSISTANT MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:56:21.159497	2025-11-12 00:56:28.749329	sitifatimah@sabahtourism.com	60138603937	siti fatimah	\N
210	1af26e62-fc99-478c-b74a-799334c11582	1	5	\N	Geraldine Lee	\N	6013-3777000	t	2025-11-05 08:06:14.17581	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Finsource", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:57:29.439459	2025-11-05 08:06:14.176552	\N	60133777000	geraldine lee	\N
662	d8519ba2-3f98-4fd9-8613-b0c68a06ef05	1	1	\N	Leonard Sim	Khiong_85@yahoo.com	60168513939	t	2025-11-07 00:01:05.445953	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Miri SpecVision Optometry ", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:56:29.75536	2025-11-07 00:01:05.446705	khiong_85@yahoo.com	60168513939	leonard sim	\N
820	12949ddc-82ee-4976-ae82-a0fb3ebdfbbe	1	1	\N	Nora Binti Bahat@martin	Nora.Bahat@sabah.gov.my	60189735673	t	2025-11-07 02:57:15.994087	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH CULTURAL BOARD", "position": "Clerk", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:56:54.008595	2025-11-07 02:57:15.994867	nora.bahat@sabah.gov.my	60189735673	nora binti bahat@martin	\N
1294	e8318d58-0d3d-4266-9895-acdf22c4d02a	1	3	\N	Chai Jee Choon	\N	60198803498	t	2025-11-08 01:01:00.270913	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Paumin Hardware Sdn Bhd", "position": "MD"}	2025-11-08 01:00:45.442982	2025-11-08 01:01:00.27165	\N	60198803498	chai jee choon	\N
149	719a0144-0efd-4e89-88af-0b3e6fba8a9b	1	1	\N	Tan Yinglin	\N	60129027095	t	2025-11-07 00:12:18.256267	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Evopoint Sdn Bhd", "position": "Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:01:44.215694	2025-11-07 00:12:18.256868	\N	60129027095	tan yinglin	\N
181	31d81147-4435-4852-9896-3381d0e59add	1	1	\N	Sylvester Linus	\N	60168383857	t	2025-11-12 01:49:54.86759	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KINARA ENERGY SDN BHD", "position": "MANAGING DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:57:35.665991	2025-11-12 01:50:15.741173	\N	60168383857	sylvester linus	\N
142	128382f9-2f56-45c4-92fa-0134d2a04402	1	1	\N	AnJoe Ang See Rune	\N	60176347469	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Lok Kawi Plastic Industries Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:55:20.604973	2025-11-03 06:55:20.604973	\N	60176347469	anjoe ang see rune	\N
145	a2b76a56-cc23-4772-81a3-70a4888c3252	1	1	\N	JASON TAI BING REN	\N	60178028088	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "UNIANG PLASTIC INDUSTRIES SDN BHD", "position": "SALES MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 06:57:34.715027	2025-11-03 06:57:34.715027	\N	60178028088	jason tai bing ren	\N
663	0f28414a-9e96-46d1-a392-6ea29f72da02	1	1	\N	Ng Kai Loom	thepoolmy@yahoo.co.uk	60126356262	t	2025-11-07 00:02:22.213331	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Miri SpecVision Optometry", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:00.358042	2025-11-07 00:02:22.213941	thepoolmy@yahoo.co.uk	60126356262	ng kai loom	\N
191	e6f86d9b-ffae-4c39-875b-6d65686f55a1	1	1	\N	Vivi	Valynna@ga.com.my	6088363306	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:13:05.219529	2025-11-12 00:55:51.092439	valynna@ga.com.my	6088363306	vivi	\N
665	062b7b7d-fa74-4891-9864-f0f047687cb7	1	1	\N	Mimi Zarina Binti Bakri	mimizarina@tarc.edu.my	60138501085	t	2025-11-07 00:05:09.384085	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TAR UMT SABAH BRANCH", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:04.602456	2025-11-07 00:05:09.384859	mimizarina@tarc.edu.my	60138501085	mimi zarina binti bakri	\N
666	58d67ff5-f516-4aca-b906-e537ddee7052	1	1	\N	Nur Iezatie Arysha Nazira	iezatie99@gmail.com	601151707671	t	2025-11-07 00:01:50.308515	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Miri Specvision Optometry", "position": "QC and Operation", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:04.794929	2025-11-07 00:01:50.309212	iezatie99@gmail.com	601151707671	nur iezatie arysha nazira	\N
668	460ca4d6-859e-483c-a586-89b6c869547e	1	1	\N	Zulhizaji Mohd Salleh	Zulhizaji@poic.com.my	60168303144	t	2025-11-07 00:04:07.472803	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "POIC SABAH SDN BHD", "position": "Executive, IT & Resource Center", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:25.750712	2025-11-07 00:04:07.473515	zulhizaji@poic.com.my	60168303144	zulhizaji mohd salleh	\N
1190	a8655892-0513-402c-b4eb-7b4505217702	1	1	\N	Abdul Ghaffar	rinapapay313@gmail.com	60169403919	t	2025-11-07 10:35:32.308596	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Asoib 313 Enterprise ", "position": "Manager "}	2025-11-07 10:34:51.023267	2025-11-07 10:35:32.30921	rinapapay313@gmail.com	60169403919	abdul ghaffar	\N
690	690de638-30d7-4d29-9d5f-c2fd17493f13	1	1	\N	Lanah Sungkoling	lanah.sungkoling@sabah.gov.my	60138511078	t	2025-11-07 00:08:01.168222	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ministry of Tourism, Culture and Environment", "position": "Pegawai Tadbir", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:02:57.008014	2025-11-07 00:08:01.169059	lanah.sungkoling@sabah.gov.my	60138511078	lanah sungkoling	\N
698	db5a3770-7aab-42cc-ba28-39164f0851a5	1	1	\N	Grace Lim	Gracelim27@live.com	60178199100	t	2025-11-07 00:06:38.264821	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Mega Hopes Sales Sdn Bhd ", "position": "Director ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:05:27.731668	2025-11-07 00:06:38.265332	gracelim27@live.com	60178199100	grace lim	\N
111	9bea7c72-656c-4e02-8a80-08af0e59f33f	1	4	\N	Nurfaizatul Syuhada Binti Awang Sham	\N	60165522228	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BORNEO ECO TOUR SDN BHD", "position": "", "coupon_referral": "", "business_industry": "Tourism", "print_exhibitor_tag": ""}	2025-11-02 04:24:48.056715	2025-11-12 01:04:39.05994	\N	60165522228	nurfaizatul syuhada binti awang sham	\N
103	e36d2fe7-14fb-48e4-8cfa-0252a872de26	1	4	\N	Sharifah Faizatul Nazihah binti Wan Abdul Hamid	\N	60146299185	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Torr Energy Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "Oil & Gas", "print_exhibitor_tag": ""}	2025-11-02 04:11:01.486716	2025-11-02 04:11:01.486716	\N	60146299185	sharifah faizatul nazihah binti wan abdul hamid	\N
105	88b8576c-2cd4-4137-953e-a12c7391998e	1	4	\N	Anne Antah	\N	60195300018	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Chanteek Borneo Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "Manufacturing", "print_exhibitor_tag": ""}	2025-11-02 04:12:17.215653	2025-11-02 04:12:17.215653	\N	60195300018	anne antah	\N
700	bbec125a-d46f-42c9-a4ac-4c98f4a2ff2c	1	1	\N	Nur'fazlina A	nfazlina111@gmail.com	60146523361	t	2025-11-07 00:05:43.524333	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "AMAZING BORNEO TOURS & EVENTS SDN BHD", "position": "SUPERVISOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:05:43.524333	2025-11-07 00:05:43.524333	nfazlina111@gmail.com	60146523361	nur'fazlina a	\N
107	cf092591-8928-4a1c-97f3-5a8fd8a795df	1	4	\N	Judith Philomena A.bansing	\N	60169715001	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "BORNEO ECO TOUR SDN BHD", "position": "", "coupon_referral": "", "business_industry": "Tourism", "print_exhibitor_tag": ""}	2025-11-02 04:14:16.10576	2025-11-12 01:04:43.453723	\N	60169715001	judith philomena a.bansing	\N
209	3c3975f2-b094-4f36-aec3-2231012f9d77	1	5	\N	Wong Yoke Hoe	\N	6016-9809657	t	2025-11-05 08:05:21.665194	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Finsource", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 08:56:29.523118	2025-11-05 08:05:21.665834	\N	60169809657	wong yoke hoe	\N
821	2a11fb23-9fd5-4571-bf90-052b85595758	1	1	\N	Nency F. Edward	nfirstinaed24@gmail.com	60189627824	t	2025-11-07 02:57:49.168663	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "KERANI", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:57:12.094166	2025-11-07 02:57:49.169362	nfirstinaed24@gmail.com	60189627824	nency f. edward	\N
840	dff16fa8-e709-4906-b49e-472d1f2c05c2	1	1	\N	Joel Yong	joelyong28@gmail.com	60168125802	t	2025-11-07 03:10:00.723825	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Harvest Horizon", "position": "General Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:09:38.116632	2025-11-07 03:10:00.724524	joelyong28@gmail.com	60168125802	joel yong	\N
856	2c7f75bc-d39b-4c9a-abf0-8e9c8f4af5cc	1	1	\N	Kennt Yong Khui Ming	kenntyong112@gmail.com	601170396316	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "TARUMT SABAH", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:16:08.817053	2025-11-07 03:16:08.817053	kenntyong112@gmail.com	601170396316	kennt yong khui ming	\N
861	3e0b342a-ed12-4912-8ed6-f1b55eee9c5f	1	1	\N	Steven Wong Chen Loong	Stevenwong556@gmail.com	60165092481	t	2025-11-07 03:19:24.831943	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "IPSOS SDN BHD", "position": "Survey officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:18:59.50231	2025-11-07 03:19:24.83251	stevenwong556@gmail.com	60165092481	steven wong chen loong	\N
889	b7f1d2b8-0db6-4311-becf-901cc10a7ffd	1	1	\N	Jowez Lee	Jowezlky14@gmail.com	60168332793	t	2025-11-07 06:02:44.307425	26	1	1	\N	\N	\N	{"role": "VIP", "company": "Mtpn", "position": "Private tutor ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:56:46.806894	2025-11-07 06:02:44.308125	jowezlky14@gmail.com	60168332793	jowez lee	\N
949	6fd73185-ac83-46f6-8950-90fcce913909	1	1	\N	Ivy Chang Qi Jun	Changqj21@gmail.com	601125241362	t	2025-11-07 05:26:06.339293	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Media ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:22:02.371933	2025-11-07 05:26:06.339932	changqj21@gmail.com	601125241362	ivy chang qi jun	\N
952	783843af-8edd-451b-8b10-0f46962bd0b3	1	1	\N	Sh Syaza	shsyaza_fatimah@yahoo.com	60127966032	t	2025-11-07 05:31:08.153165	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "BAKER TILLY SABAH", "position": "ACCOUNT ASSOCIATES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:23:03.380607	2025-11-07 05:31:08.153829	shsyaza_fatimah@yahoo.com	60127966032	sh syaza	\N
953	94ad46d3-ec33-40db-9e2c-3fd90e1a4b63	1	1	\N	Dayang Hazelliyana Syafirah	dhazel2210@gmail.com	60122109879	t	2025-11-07 05:23:33.27267	26	1	1	\N	\N	\N	{"role": "Student", "company": "Maktab Sabah", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:23:05.827468	2025-11-07 05:23:33.273396	dhazel2210@gmail.com	60122109879	dayang hazelliyana syafirah	\N
955	fd357a7d-8633-41e7-b78b-1e97f0b0a62e	1	1	\N	Nile	argon.olivro@gmail.com	60136267747	f	\N	\N	0	1	\N	\N	\N	{"role": "Option 6", "company": "Jumping Joy", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:24:45.434511	2025-11-07 05:24:45.434511	argon.olivro@gmail.com	60136267747	nile	\N
956	79e4f811-cad8-433f-896a-02da0ac79ee2	1	1	\N	Haryati	Yatsmel@yahoo.com	60128203596	t	2025-11-07 05:25:06.663648	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "A", "position": "A", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:24:48.848174	2025-11-07 05:25:06.664268	yatsmel@yahoo.com	60128203596	haryati	\N
957	b94a4609-2fb1-498f-a207-cd2a25db1d38	1	1	\N	Nathaniel Kou	Nathanielkou6@gmail.com	60173025150	t	2025-11-07 05:26:19.618944	23	1	1	\N	\N	\N	{"role": "Student", "company": "Asia pacific university", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:25:48.549868	2025-11-07 05:26:19.619894	nathanielkou6@gmail.com	60173025150	nathaniel kou	\N
959	b95bf818-36ec-4ee9-b9d2-df442bd2af83	1	1	\N	Madztrofel Binti Mohd Usin	hidayahkasih_92@yahoo.com	60143900292	t	2025-11-07 05:28:51.535725	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "GA GROUP", "position": "ACCOUNT ASSOCIATES ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:28:09.480714	2025-11-07 05:28:51.536407	hidayahkasih_92@yahoo.com	60143900292	madztrofel binti mohd usin	\N
960	94ca663b-4c8d-4749-8eea-0adf32f941a5	1	1	\N	Erica Richard	ericarichard78@gmail.com	60109751690	t	2025-11-07 05:30:36.556461	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly Sabah", "position": "Tax Intern", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:30:20.585148	2025-11-07 05:30:36.557103	ericarichard78@gmail.com	60109751690	erica richard	\N
962	b24f1df9-f873-4190-9c90-4e0cb71f6b27	1	1	\N	Tsen Lip Thou Paul	tsenpaul@yahoo.com	60198537592	t	2025-11-07 05:34:03.523968	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Independent Engineering Consultancy ", "position": "Owner/Water Engineer ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:33:46.476848	2025-11-07 05:34:03.524615	tsenpaul@yahoo.com	60198537592	tsen lip thou paul	\N
1003	785639bd-ebba-4bfc-a975-33148ab347ec	1	1	\N	Nurul Azyan Najian	azyannajian@gmail.con	60195985606	t	2025-11-07 06:30:53.969826	29	1	1	\N	\N	\N	{"role": "Student", "company": "UiTM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:30:22.352148	2025-11-07 06:30:53.970462	azyannajian@gmail.con	60195985606	nurul azyan najian	\N
1005	02a4a3d0-4f65-45c9-a3ca-5e0324d259b3	1	1	\N	Nur Irdina Aqilah	dynaasran@gmail.com	60103706778	t	2025-11-07 06:30:51.432163	29	1	1	\N	\N	\N	{"role": "Student", "company": "UiTM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:30:23.053744	2025-11-07 06:30:51.432757	dynaasran@gmail.com	60103706778	nur irdina aqilah	\N
1036	bdd2d9f5-c34b-49f9-9050-384133f26885	1	1	\N	Norazlina	Norazlinalina13@gmail.com	601125233762	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Ums", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:04:12.024079	2025-11-07 07:04:12.024079	norazlinalina13@gmail.com	601125233762	norazlina	\N
841	7dab58ff-2f0b-4999-8425-d713e8c26ba5	1	1	\N	Noor Hasyim	hasyim.miysahh@gmail.com	60146387578	t	2025-11-07 03:10:50.953516	29	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "BANK RAKYAT", "position": "Executive SME", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:09:58.9518	2025-11-07 03:10:50.954096	hasyim.miysahh@gmail.com	60146387578	noor hasyim	\N
842	34d5a9e2-d06e-4737-8f7f-a5abcc82696c	1	1	\N	Ang Yang	angyang0380@gmail.com	60173420380	t	2025-11-07 03:10:26.668963	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Harvest horizon sdn bhd", "position": "Mananger ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:10:03.522004	2025-11-07 03:10:26.6698	angyang0380@gmail.com	60173420380	ang yang	\N
843	364563e9-43d8-4b79-876a-a56c5b018067	1	1	\N	Noor Ardilah Binti Radzwan	dilaradzzwan@icloud.com	60123280310	t	2025-11-07 03:10:42.226315	29	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Bank Rakyat", "position": "Vice President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:10:19.974498	2025-11-07 03:10:42.226927	dilaradzzwan@icloud.com	60123280310	noor ardilah binti radzwan	\N
844	945c45a7-5a4f-4333-8be9-624a2bd60a65	1	1	\N	Janett Jackson	Elvinchin94@gmail.com	60196041352	t	2025-11-07 03:11:20.504011	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ripoff printism", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:10:58.086905	2025-11-07 03:11:20.504617	elvinchin94@gmail.com	60196041352	janett jackson	\N
854	dd904b5b-bba1-4571-bde4-744217d69283	1	1	\N	Alex Kong Jiehong	alexkj-sb23@student.tarc.edu.my	601151679227	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:15:44.13901	2025-11-07 03:15:44.13901	alexkj-sb23@student.tarc.edu.my	601151679227	alex kong jiehong	\N
855	9aa2ca15-8f41-409e-9370-cda969723c56	1	1	\N	Jeriel Liew Ee Nuo	jeriellen-sj24@student.tarc.edu.my	60102722660	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:15:52.200803	2025-11-07 03:15:52.200803	jeriellen-sj24@student.tarc.edu.my	60102722660	jeriel liew ee nuo	\N
862	6d200913-834c-4cea-970c-543f0eae3162	1	1	\N	Cassandra Clarence	dclegacyenterprise@gmail.com	60148530483	t	2025-11-07 03:21:39.571678	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "CASEY'S CAFE", "position": "OWNER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:21:19.068593	2025-11-07 03:21:39.572242	dclegacyenterprise@gmail.com	60148530483	cassandra clarence	\N
864	0add4ec3-bd30-4c4f-b095-9229e757cbf9	1	1	\N	Annie Ng	annieng@namheng.my	60168332862	t	2025-11-07 03:26:08.343513	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "NAM HENG SAFETY GLASS (SABAH) SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:25:13.377444	2025-11-11 07:09:17.32152	annieng@namheng.my	60168332862	annie ng	\N
865	d6b60e4b-fc5f-4d4c-a5b4-9d71c8a5a283	1	1	\N	Emmanuel Ajac	berjiriajutagroup@gmail.com	601133243288	t	2025-11-07 03:27:29.793417	29	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Berjiria juta Group ", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:25:45.379599	2025-11-07 03:27:29.794069	berjiriajutagroup@gmail.com	601133243288	emmanuel ajac	\N
872	019723ad-4930-4e89-a3de-fdc206cb69bc	1	1	\N	Alvin Lim	alvin_lch@live.com.my	60167243119	t	2025-11-11 06:07:28.568296	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Cotra Enterprise Sdn Bhd", "position": "Assist Regional Foodservice manager "}	2025-11-07 03:32:12.255679	2025-11-11 06:07:28.569179	alvin_lch@live.com.my	60167243119	alvin lim	\N
867	8bb1c701-f0a5-46e4-9780-cf6f88c896ad	1	1	\N	Chang Yan Ming	skychangandfriend@gmail.com	60166400518	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:28:08.969999	2025-11-07 03:28:08.969999	skychangandfriend@gmail.com	60166400518	chang yan ming	\N
868	b2957b4c-f273-4b7f-a4d1-3ab8fbc8d747	1	1	\N	Reynold Valentine Chin	rvalentinechin@gmail.com	60198433344	t	2025-11-07 03:30:31.717602	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "IFCA SOLUTION SDN BHD", "position": "BUSINESS DEVELOPMENT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:29:55.944981	2025-11-07 03:30:31.718409	rvalentinechin@gmail.com	60198433344	reynold valentine chin	\N
874	855ac293-8d32-46b6-aa3d-3570ea231ca5	1	1	\N	Shirley Ho Schac Li	shirley.ho@sabahtourism.com	60178399055	t	2025-11-07 03:50:58.231416	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:36:36.778449	2025-11-12 00:52:19.788459	shirley.ho@sabahtourism.com	60178399055	shirley ho schac li	\N
870	0c8a7a25-2db1-4153-bf15-800971d00dc7	1	1	\N	Nurrina Sanati	nurrina240@gmail.com	60147726766	t	2025-11-07 03:31:18.311996	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Berjiria Juta Group", "position": "Secretary ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:30:26.214991	2025-11-07 03:31:18.312817	nurrina240@gmail.com	60147726766	nurrina sanati	\N
869	6dcf2e65-f127-4937-ac72-da8a2f8443f9	1	1	\N	Asnor Nasha Binti Ag Sarpuddin	asnornashamy@gmail.com	60138880099	t	2025-11-07 03:30:35.347754	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "KKIP SDN BHD", "position": "OFFICER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:29:57.141513	2025-11-12 00:31:03.033609	asnornashamy@gmail.com	60138880099	asnor nasha binti ag sarpuddin	\N
875	479c4d42-7e37-4b28-b7bc-fbca89d1f0e6	1	1	\N	Royna Masbud	workraimas@gmail.com	601161130711	t	2025-11-07 03:41:35.216848	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Raimas food industry", "position": "Ceo", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:41:00.480804	2025-11-07 03:41:35.217499	workraimas@gmail.com	601161130711	royna masbud	\N
876	4566d3ed-ece6-4c27-ba6c-45e914c7a783	1	1	\N	Mokhtar Mannan	Mokhtarmannan@gmail.com	60198813707	t	2025-11-07 03:42:00.71995	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Puncak Billion", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:41:28.385509	2025-11-07 03:42:00.720714	mokhtarmannan@gmail.com	60198813707	mokhtar mannan	\N
963	692fe52b-3617-4611-a7da-4bd21715095c	1	1	\N	Qasdiena	qasdienaq@gmail.com	60128136497	t	2025-11-07 05:34:54.862395	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Aforce Realty", "position": "property advisor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:34:36.159323	2025-11-07 05:34:54.862995	qasdienaq@gmail.com	60128136497	qasdiena	\N
966	969508c1-8d11-4ecf-bae8-ea934ed6995c	1	1	\N	Rita	ritadymphna@gmail.com	60168202966	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Rimbunan warisan", "position": "Exhibitor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:40:38.909911	2025-11-07 05:40:38.909911	ritadymphna@gmail.com	60168202966	rita	\N
1049	fbc86ee7-1d78-4836-ab40-71a092834798	1	2	\N	Andrew Ang	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ang Systems", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:26:44.201939	2025-11-07 07:26:44.201939	\N	\N	andrew ang	\N
1082	575bb270-b8b2-45de-9699-ee6cfc4613ce	1	3	\N	Graiven Lo	\N	\N	t	2025-11-07 10:47:12.742431	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.158565	2025-11-07 10:47:12.743117	\N	\N	graiven lo	\N
847	6a22fc06-8274-4d44-b6e7-a65cb1f6e29b	1	1	\N	Ninah Kiram	ninahkiram67@gmail.com	60162690014	t	2025-11-07 03:13:53.785393	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BTC MAJU HOLDING SDN BHD", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:13:05.392208	2025-11-07 03:13:53.786063	ninahkiram67@gmail.com	60162690014	ninah kiram	\N
850	4dce3c30-4a39-4e09-bbf5-09d919941a6e	1	1	\N	Alvan Chin Jia Hoong	alvancjh@gmail.com	601126160833	t	2025-11-07 03:18:25.719123	29	1	1	\N	\N	\N	{"role": "Student", "company": "TUNKU ABDUL RAHMAN UNIVERSITY OF TECHNOLOGY AND MANAGEMENT ", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:13:58.273447	2025-11-07 03:18:25.719813	alvancjh@gmail.com	601126160833	alvan chin jia hoong	\N
851	d3ebe611-a4e6-4601-ac31-acc6faf895b6	1	1	\N	Hannah Abygaile Philimon	abygailhannah@gmail.com	60123837155	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sabah Institute of Art", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:14:49.206838	2025-11-07 03:14:49.206838	abygailhannah@gmail.com	60123837155	hannah abygaile philimon	\N
852	97ebd006-6211-4b07-ad33-97409e215689	1	1	\N	Jullizah Binti Sukari	insprisechofliss@gmail.com	60162949065	t	2025-11-07 03:21:01.75203	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "INSPRISE TOP GLOB", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:15:05.767712	2025-11-07 03:21:01.752696	insprisechofliss@gmail.com	60162949065	jullizah binti sukari	\N
853	8439e8bd-a2c8-470e-9e85-8578066d58e0	1	1	\N	Jerrick Harry Piti	jerrickjerry71@gmail.com	60168030995	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sabah institue of arts", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:15:09.221756	2025-11-07 03:15:09.221756	jerrickjerry71@gmail.com	60168030995	jerrick harry piti	\N
858	98db28cb-2a40-45bc-b0ce-c3eac5f66206	1	1	\N	Abbygail	abbygailchristy161205@gmail.com	60168200909	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:16:45.133289	2025-11-07 03:16:45.133289	abbygailchristy161205@gmail.com	60168200909	abbygail	\N
859	838c887f-f945-4e58-b372-67bb5b5ae3a2	1	1	\N	Gregory Scott	Gregoryscott9211@gmail.com	60146916742	t	2025-11-07 03:17:26.025195	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "XBG", "position": "Creative", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:17:01.977492	2025-11-07 03:17:26.025817	gregoryscott9211@gmail.com	60146916742	gregory scott	\N
1193	265e6294-ed66-4f28-b72d-99f33650a55f	1	1	\N	Amy Liaw	hagstore@gmail.com	60102001555	t	2025-11-07 11:00:31.505563	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "HAG STORE SDN BHD", "position": "Director"}	2025-11-07 11:00:31.505563	2025-11-07 11:00:31.505563	hagstore@gmail.com	60102001555	amy liaw	\N
878	03bde7d9-4699-4907-9736-9bd807338e8c	1	1	\N	Dorra Roman	Theodora.boniface@sabah.gov.my	60192883390	t	2025-11-07 03:43:33.641076	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Kementerian Pembangunan Perindustrian dan Keusahawanan", "position": "Officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:43:02.109738	2025-11-07 03:43:33.641592	theodora.boniface@sabah.gov.my	60192883390	dorra roman	\N
863	cd90dfd4-74e8-4882-b069-5027df50245a	1	1	\N	Cassie Chin	Cassie838.mcbsb@gmail.com	60109310488	t	2025-11-07 03:23:41.2776	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MEGA CITY BUILDER SDN BHD", "position": "SALES & SOCIAL MEDIA EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:23:19.838956	2025-11-11 08:21:11.139336	cassie838.mcbsb@gmail.com	60109310488	cassie chin	\N
879	85359cc2-aa49-4cb0-975f-a91d4c08916c	1	1	\N	Kevin Khor	Kevinkhorjj@gmail.con	60178208460	t	2025-11-07 03:46:56.62899	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lv partners", "position": "Partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:46:03.552555	2025-11-07 03:46:56.629641	kevinkhorjj@gmail.con	60178208460	kevin khor	\N
882	31aec1a8-93bd-419f-a125-8b3d3288a9c0	1	1	\N	Mackey Apison	Mackey.Apison@sabah.gov.my	60168249277	t	2025-11-07 03:53:11.154574	30	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "GENERAL MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:52:39.401585	2025-11-07 03:53:11.155538	mackey.apison@sabah.gov.my	60168249277	mackey apison	\N
883	bc2aa69b-da08-448d-81b4-a320f22a7b71	1	1	\N	Mailin Binti Soborong	mailinsoborong1971@gmail.com	60108861828	t	2025-11-07 03:54:51.414181	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Molin's kraf enterprise ", "position": "Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:54:30.706989	2025-11-07 03:54:51.414804	mailinsoborong1971@gmail.com	60108861828	mailin binti soborong	\N
884	bb6b9923-5a49-4ed2-b146-b193e005fdc9	1	1	\N	Iyvette Lesley Chin	Iyvettechin@gmail.com	60125061773	t	2025-11-07 03:56:56.627146	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ipsos Sdn Bhd", "position": "Survey Officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:55:11.689406	2025-11-07 03:56:56.627736	iyvettechin@gmail.com	60125061773	iyvette lesley chin	\N
885	c62f1642-5b6d-4a21-b054-ef55d3fac3de	1	1	\N	Iyvonne Chin	iyvonnep@yahoo.com	60132367986	t	2025-11-07 03:56:35.096879	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ipsos sdn bhd", "position": "Survey officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:55:13.352621	2025-11-07 03:56:35.097428	iyvonnep@yahoo.com	60132367986	iyvonne chin	\N
886	a3ce52f3-bd5b-4e38-bf8c-31b73032dfca	1	1	\N	Ernawaty Suhaili	erna.suhai@gmail.com	60168322420	t	2025-11-07 03:56:07.350483	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "POIC", "position": "Assistant Manager, Research and Information", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:55:27.744032	2025-11-07 03:56:07.351037	erna.suhai@gmail.com	60168322420	ernawaty suhaili	\N
887	d8204246-c726-43fd-811f-39f710afac44	1	1	\N	Suzane	Suzanebunny87@gmail.com	601169376689	t	2025-11-07 03:55:56.16644	30	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "De'resepi", "position": "Pemasaran", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:55:32.21684	2025-11-07 03:55:56.166935	suzanebunny87@gmail.com	601169376689	suzane	\N
890	66325356-d719-4461-ae69-06f674190cd5	1	1	\N	Siti Nur Afidah Binti Sahbudin	afidah@sedia.com.my	60178158042	t	2025-11-07 03:57:57.105251	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Economic Development and Investment Authority (SEDIA)", "position": "Senior Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:57:42.615535	2025-11-07 03:57:57.107051	afidah@sedia.com.my	60178158042	siti nur afidah binti sahbudin	\N
965	9eefbf9f-3f6b-4b44-a5b5-d283857e4441	1	1	\N	Jaikoh Alexander Giat	alexandergiat@yahoo.com	60138688374	t	2025-11-07 05:38:08.870678	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Rimbunan Warisan", "position": "Promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:37:30.359967	2025-11-07 05:38:08.871281	alexandergiat@yahoo.com	60138688374	jaikoh alexander giat	\N
1083	2c11dc5a-f0a9-499f-8524-f3ad984749a3	1	3	\N	Sophia Tan	\N	\N	t	2025-11-07 10:52:07.112241	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.165079	2025-11-07 10:52:07.112965	\N	\N	sophia tan	\N
895	3c3a87d5-858d-4612-86fd-fe3c42961e47	1	1	\N	Walter John	walter@sabahtourism.com	60198817423	t	2025-11-07 04:01:59.754117	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "WEB DEVELOPMENT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:01:36.279513	2025-11-12 00:52:42.264075	walter@sabahtourism.com	60198817423	walter john	\N
1015	f2395bf9-131b-4ac5-afcd-2dc19e6df065	1	1	\N	Elvin Lim	eltechenterprise@gmail.com	60198923232	t	2025-11-07 06:48:23.769979	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "EL-TECH ENTERPRISE", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:48:23.769979	2025-11-07 06:48:42.131417	eltechenterprise@gmail.com	60198923232	elvin lim	\N
1018	c352d6a9-bba6-430e-bf3c-eb00af230a1a	1	1	\N	Christina	Christina_ting77@hotmail.com	60104643713	t	2025-11-07 06:51:21.181398	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Foreward ", "position": "Sales ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:51:21.181398	2025-11-07 06:51:37.901502	christina_ting77@hotmail.com	60104643713	christina	\N
1059	4f80bd05-7c6c-4765-adb5-24c3c18113bf	1	1	\N	Mariamah Sedan	mariamahsedan2504@gmail.com	60107087615	t	2025-11-12 01:29:47.206443	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "ONONG RICH ENTERPRISE", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:10:37.173127	2025-11-12 01:29:47.207125	mariamahsedan2504@gmail.com	60107087615	mariamah sedan	\N
893	2e3e4e3a-da6e-49bd-a09c-436ecd22e74d	1	1	\N	Donald Ng	mmksb@hotmail.com	60167709660	t	2025-11-07 04:01:08.61363	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Megamas Konsult Sb", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:00:05.469459	2025-11-07 04:01:08.615033	mmksb@hotmail.com	60167709660	donald ng	\N
894	6f1f9e78-af73-40fc-b47e-a0b0bf69c78b	1	1	\N	William	ts2339698@gmail.com	60189611978	t	2025-11-07 04:00:42.288336	23	1	1	\N	\N	\N	{"role": "VIP", "company": "Tz Enterprise ", "position": "Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:00:14.179936	2025-11-07 04:00:42.288939	ts2339698@gmail.com	60189611978	william	\N
897	f9ee9965-77d2-4551-9cfe-3838acf2aa8c	1	1	\N	Danial Bin Tius	neanceyy@gmail.com	60177723037	t	2025-11-07 04:02:29.025391	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hainan cafe ", "position": "Chef", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:02:06.285281	2025-11-07 04:02:29.026002	neanceyy@gmail.com	60177723037	danial bin tius	\N
967	eb57f11b-77bd-4633-a522-215e59b0b872	1	1	\N	One Roof Kilang Kopi	liewliling84@gmail.com	60128336003	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "One roof kopi kilang", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:40:55.917541	2025-11-07 05:40:55.917541	liewliling84@gmail.com	60128336003	one roof kilang kopi	\N
979	75037129-e25a-4d08-94cc-7a1ef95e6940	1	1	\N	Damaris Balang	dbalang@yahoo.com	601131662318	t	2025-11-07 06:06:03.073967	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Kebudayaan Lundayeh Sabah", "position": "Bendahari Agung", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:05:38.361441	2025-11-07 06:06:03.07475	dbalang@yahoo.com	601131662318	damaris balang	\N
981	1381d32a-1c84-4972-9a45-dc4665fb7b6c	1	1	\N	Maidah Binti Baridang @ Bridang	maidahbaridang69@gmail.com	60139846369	t	2025-11-07 06:07:03.246509	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Kebudayaan Lundayeh Sabah", "position": "Staff", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:06:31.342057	2025-11-07 06:07:03.247241	maidahbaridang69@gmail.com	60139846369	maidah binti baridang @ bridang	\N
1007	25fbf527-de98-4bed-bb65-ccc52e85abbe	1	1	\N	Samuel	Samuelzzx@gmail.com	60168055198	t	2025-11-07 06:39:47.849835	26	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Megah billion sdn bhd", "position": "General manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:39:30.879973	2025-11-07 06:39:47.850563	samuelzzx@gmail.com	60168055198	samuel	\N
1008	5b973705-a735-4338-9853-3d0cfbc026b2	1	1	\N	William Chung	cfchung59@gmail.com	60123621986	t	2025-11-07 06:40:05.550472	26	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Gersik Glass", "position": "Busy body", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:39:46.643483	2025-11-07 06:40:05.55111	cfchung59@gmail.com	60123621986	william chung	\N
1016	573c8eff-252b-4c6e-9aec-5d9a2c3a7acf	1	1	\N	Famela Binti Ensoss	efamla@yahoo.com	60124993934	t	2025-11-07 06:51:20.3444	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "DINAMIK ATLANTIK SDN BHD", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:50:01.029772	2025-11-07 06:51:20.34511	efamla@yahoo.com	60124993934	famela binti ensoss	\N
901	fccd79a9-7e32-4355-b5fd-e01b56e9cdec	1	1	\N	Jennifer	jennccy@gmail.com	60122413193	t	2025-11-07 04:12:59.5956	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Maybank investment bank ", "position": "Regional Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:12:10.280706	2025-11-07 04:12:59.596252	jennccy@gmail.com	60122413193	jennifer	\N
902	eda51377-43ec-4324-a33b-8998268206bc	1	1	\N	Cathrin	shirlyyy12277@gmail.com	60102147525	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "KDCA", "position": "booth 98-D", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:15:44.403869	2025-11-07 04:15:44.403869	shirlyyy12277@gmail.com	60102147525	cathrin	\N
905	24adf6dc-9ac9-493b-9a92-d1808f412793	1	1	\N	Christine	Christineusop@gmail.com	60105396059	t	2025-11-07 04:18:34.190146	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "SALES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:18:09.441809	2025-11-11 23:57:16.991712	christineusop@gmail.com	60105396059	christine	\N
1192	c49b4908-2b69-4002-8508-a98fca86f46f	1	1	\N	Calvin	calvinwongkaiwen950510@gmail.com	60149515210	t	2025-11-07 10:52:44.924757	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "City", "position": "Designer "}	2025-11-07 10:52:44.924757	2025-11-07 10:52:44.924757	calvinwongkaiwen950510@gmail.com	60149515210	calvin	\N
906	fcb06ff0-0496-4cad-a2b2-f6a976b7b0ba	1	1	\N	Cathrin	shirlyyy12277@gmail.com	60102147525	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "KDCA", "position": "booth 98-D ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:19:17.940945	2025-11-07 04:19:17.940945	shirlyyy12277@gmail.com	60102147525	cathrin	\N
908	523c485a-813f-4f4d-8c39-93a7a23bc94f	1	1	\N	Byron Chester Dee	byroncdr.sia@gmail.com	60146701300	t	2025-11-07 04:23:15.387134	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH INSTITUTE OF ART", "position": "Lecturer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:22:54.046821	2025-11-07 04:23:15.387876	byroncdr.sia@gmail.com	60146701300	byron chester dee	\N
909	54d20c20-3b67-40c0-ac03-4e5cc2f1bb94	1	1	\N	Nur Fatin Binti Abd Aziz	fatinaziz.work@gmail.com	60137122731	t	2025-11-07 04:31:41.51108	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "SIA", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:29:07.975055	2025-11-07 04:31:41.511841	fatinaziz.work@gmail.com	60137122731	nur fatin binti abd aziz	\N
910	5a052adc-112d-469c-8537-ad48296b17af	1	1	\N	Lawrence Chau	lawchau80@gmail.com	60146763628	t	2025-11-07 04:30:23.560103	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Einstronic Enterprise Sdn Bhd ", "position": "Managing Director / CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:29:30.908108	2025-11-07 04:30:23.560693	lawchau80@gmail.com	60146763628	lawrence chau	\N
911	5faa24bc-3a06-48df-abdd-fff11c8455e5	1	1	\N	Miko Lee	Mikolee@glocomp.net	60126968803	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Glocomp systems ( m) sdn bhd ", "position": "Senior channel executives ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:29:47.924783	2025-11-07 04:29:47.924783	mikolee@glocomp.net	60126968803	miko lee	\N
913	dda38a83-14a1-4ac5-89b4-04faa42076b2	1	1	\N	Thomas Lam	Thomas.Lam@ihg.com	60168908028	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "HOLIDAY INN EXPRESS KOTA KUNABALU CITY CENTRE", "position": "Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:31:40.930563	2025-11-07 04:31:40.930563	thomas.lam@ihg.com	60168908028	thomas lam	\N
915	8b9b2e6c-37e2-444e-8597-312e749fe53d	1	1	\N	Derich Shalbie	der_rich@ymail.com	60165879309	t	2025-11-07 04:36:48.306936	30	1	1	\N	\N	\N	{"role": "Student", "company": "Universiti Malaysia Sabah", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:34:59.949147	2025-11-07 04:36:48.307829	der_rich@ymail.com	60165879309	derich shalbie	\N
917	a18412a5-5ab7-4cb7-93f5-1e2ea418d0e8	1	1	\N	Noor Intan Basar	NoorIntan.Basar@sabah.gov.my	601131583853	t	2025-11-07 04:37:26.734598	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jabatan Hal Ehwal Wanita Sabah", "position": "Penolong Pengarah ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:36:30.911869	2025-11-07 04:37:26.735375	noorintan.basar@sabah.gov.my	601131583853	noor intan basar	\N
918	c88dcf4b-87c6-42f3-b892-cc588e5b51f3	1	1	\N	Nabila	Nabila.Ismail@sabah.gov.my	60109301813	t	2025-11-07 04:37:15.677998	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jabatan Hal Ehwal Wanita Sabah", "position": "Penolong pengarah", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:36:45.936676	2025-11-07 04:37:15.678689	nabila.ismail@sabah.gov.my	60109301813	nabila	\N
919	ed5110d0-19f4-4e6c-b0f1-efd00a354cda	1	1	\N	Ilynurr Vrievia M.h Subari	Ilynurr.subari@sabah.gov.my	601119550977	t	2025-11-07 04:37:33.385689	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jabatan hal ehwal wanita", "position": "Penolong pengarah", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:37:08.483283	2025-11-07 04:37:33.386447	ilynurr.subari@sabah.gov.my	601119550977	ilynurr vrievia m.h subari	\N
920	6aa4081d-736f-477b-8e7b-2c8206357cfc	1	1	\N	Siti Asyurah	meyronisa@gmail.com	60146728729	t	2025-11-07 04:40:54.137747	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Women's Affair Department", "position": "Administrative Officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:40:37.749578	2025-11-07 04:40:54.138402	meyronisa@gmail.com	60146728729	siti asyurah	\N
921	f2ef22af-02aa-4488-9c91-ce3e3197cc3f	1	1	\N	Saw Hui Woon	rs1210@ymail.com	60168408568	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Kam sam enterprise", "position": "Purchasing", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:49:06.790588	2025-11-07 04:49:06.790588	rs1210@ymail.com	60168408568	saw hui woon	\N
923	f75cacb0-3566-4399-afa3-5269c7db15c6	1	1	\N	Jenny	jennychaii06@gmail.com	60175349825	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cheong Huang Comprehensive (Hainan Cafe)", "position": "Supervisor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:50:01.688831	2025-11-07 04:50:01.688831	jennychaii06@gmail.com	60175349825	jenny	\N
924	08a9468c-a5e7-4faa-acc9-b3b0c1e3d46f	1	1	\N	Koh Ah Kooi	kohahkooi@yahoo.com	60168440868	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "kam sam enterprise", "position": "director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:50:29.792456	2025-11-07 04:50:29.792456	kohahkooi@yahoo.com	60168440868	koh ah kooi	\N
925	a25066e4-43a0-466c-a7ac-a71e0c17e5a7	1	1	\N	Alya Fatna	Alyafatna@gmail.com	60177653133	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cheong Huang Compresive( Hainan Cafe )", "position": "Barista ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:50:30.443846	2025-11-07 04:50:30.443846	alyafatna@gmail.com	60177653133	alya fatna	\N
927	16fd513a-3c85-4d12-ad9a-d1bb2a136d2c	1	1	\N	Saw Hui Ting	gon_saw@yahoo.com	60168408568	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Gon saw", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:52:50.835145	2025-11-07 04:52:50.835145	gon_saw@yahoo.com	60168408568	saw hui ting	\N
969	42b5b834-5953-4995-bb66-661fb6410dfc	1	1	\N	Esterline	esterlinekapat@gmail.com	60168145775	t	2025-11-07 05:48:12.794309	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Bukit bantayan residence", "position": "Promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:47:48.725279	2025-11-07 05:48:12.795081	esterlinekapat@gmail.com	60168145775	esterline	\N
983	c04b6a03-dedc-4250-b147-228328de7d85	1	1	\N	Noraine Lasong	norainelasong@gmail.com	60138756974	t	2025-11-07 06:11:59.094703	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "PKLS", "position": "Staff", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:11:33.969644	2025-11-07 06:11:59.095681	norainelasong@gmail.com	60138756974	noraine lasong	\N
989	8e7e9c61-79cd-4d64-a862-51d15993f3e3	1	1	\N	Sofea Aguilera	sofeasoo23@gmail.com	601126070423	t	2025-11-07 06:19:54.968508	29	1	1	\N	\N	\N	{"role": "Student", "company": "UiTM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:19:10.962377	2025-11-07 06:19:54.969103	sofeasoo23@gmail.com	601126070423	sofea aguilera	\N
991	e0f19d2a-9605-4610-aeff-f3c2bad9c877	1	1	\N	Puteri Alieya Natasha	alieyanatasha66@gmail.com	60143501709	t	2025-11-07 06:19:54.494974	26	1	1	\N	\N	\N	{"role": "Student", "company": "UiTM Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:19:20.013299	2025-11-07 06:19:54.495693	alieyanatasha66@gmail.com	60143501709	puteri alieya natasha	\N
992	e9a209cc-91e7-484f-a625-9ebee58f2d3d	1	1	\N	Nazreen Shah	snazreen72@gmail.con	60198611629	t	2025-11-07 06:20:06.024246	29	1	1	\N	\N	\N	{"role": "Student", "company": "UiTM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:19:30.008044	2025-11-07 06:20:06.025025	snazreen72@gmail.con	60198611629	nazreen shah	\N
993	a9163266-ba2d-49c7-a861-86a8000ebf30	1	1	\N	Izzah Syafieqah	syafieqahmy@gmail.com	60128125479	t	2025-11-07 06:20:15.406548	26	1	1	\N	\N	\N	{"role": "Student", "company": "universiti teknologi mara", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:19:41.782437	2025-11-07 06:20:15.407131	syafieqahmy@gmail.com	60128125479	izzah syafieqah	\N
998	f42c3fce-d35a-4378-bbe1-e6e271b94b5e	1	1	\N	Alwan	alwan310803@gmail.com	60168883172	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UiTM Sabah", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:26:40.428112	2025-11-07 06:26:40.428112	alwan310803@gmail.com	60168883172	alwan	\N
1009	ddbabd80-e253-4bf5-80e2-31130ec0ed0f	1	1	\N	Azzad Zakwan	azdzkwn@gmail.com	601110205430	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Uitm", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:41:40.500288	2025-11-07 06:41:40.500288	azdzkwn@gmail.com	601110205430	azzad zakwan	\N
1011	0e74848a-28c9-43d8-9afd-f89efd150a68	1	1	\N	Oswald Joily	oswaldjoily971@gmail.com	60132835941	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UiTM", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:42:06.211446	2025-11-07 06:42:06.211446	oswaldjoily971@gmail.com	60132835941	oswald joily	\N
1219	b69645fe-5001-4da3-ae1b-4b17f73f2031	1	3	\N	Jenny Lim	\N	60146929088	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Unit Pemimpin Pembangunan Masyarakat N19 Likas ", "position": "Pemaju Mukim "}	2025-11-08 00:22:11.811567	2025-11-08 00:22:11.811567	\N	60146929088	jenny lim	\N
997	52746460-101e-4c67-838b-2740a63a443d	1	1	\N	Caroline Fredrick	caroline.fredrick@midf.com.my	60178963318	t	2025-11-12 01:18:01.356401	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MIDF", "position": "RELATIONSHIP MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:25:17.137548	2025-11-12 01:18:01.357096	caroline.fredrick@midf.com.my	60178963318	caroline fredrick	\N
929	8e8d20fd-2ad3-4b57-b597-5a5de44bcb33	1	1	\N	Frank Madan	frank_madan@yahoo.com	60123667825	t	2025-11-07 05:00:18.640147	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Fazbuzz Media", "position": "Mgr", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:59:59.727074	2025-11-07 05:00:18.640967	frank_madan@yahoo.com	60123667825	frank madan	\N
930	ba2165d3-ea3f-40fe-ae1d-4b7769251898	1	1	\N	Nadzrul	nadsee2910@gmail.com	601151780946	t	2025-11-07 05:01:28.276748	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SKG GREEN SDN BHD", "position": "Marketing", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:00:35.020121	2025-11-07 05:01:28.277255	nadsee2910@gmail.com	601151780946	nadzrul	\N
931	f77608ca-2c76-4318-a37b-88c3e8230f20	1	1	\N	Alicia Bte Lenson	akademijahitankk@yahoo.com	60168104661	t	2025-11-07 05:01:57.775982	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "JHEWA", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:01:33.147957	2025-11-07 05:01:57.776612	akademijahitankk@yahoo.com	60168104661	alicia bte lenson	\N
932	7ab2e0d7-6855-4df3-b126-7a0eeef1bc95	1	1	\N	Stella J	stelllajaprin@gmail.com	60148532019	t	2025-11-07 05:02:07.323729	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "JHEWA", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:01:39.114666	2025-11-07 05:02:07.324387	stelllajaprin@gmail.com	60148532019	stella j	\N
934	91e4bc62-a100-426b-a98c-71ac7523b18a	1	1	\N	Kenneth Chiu	chiukennethsc@gmail.com	60143700137	t	2025-11-07 05:05:52.295568	26	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Thaiseng Supermarket Sdn. Bhd.", "position": "Executive Director ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:05:20.690947	2025-11-07 05:05:52.296227	chiukennethsc@gmail.com	60143700137	kenneth chiu	\N
935	530c8ba8-b20c-44b9-9967-1448445ca267	1	1	\N	Vennessa Kanesan	vanessashak93@gmail.com	60168282885	t	2025-11-07 05:06:14.318691	26	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Warisan Wira Security Sdn Bhd", "position": "Account Executives", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:05:49.495983	2025-11-07 05:06:14.319259	vanessashak93@gmail.com	60168282885	vennessa kanesan	\N
936	1fecf518-6747-402a-89b5-2bbe0a6f1dad	1	1	\N	Ernie Syufina	ernie.sstc@gmail.com	60109576573	t	2025-11-07 05:06:56.081039	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Skills & Technology Centre", "position": "Administrative", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:06:10.982654	2025-11-07 05:06:56.081837	ernie.sstc@gmail.com	60109576573	ernie syufina	\N
938	efd6b746-ab92-40c2-beb7-7642c3787a6f	1	1	\N	Effi Nur Shazleen Binti Salleh	effi.sstc@gmail.com	601131482206	t	2025-11-07 05:08:11.669185	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH SKILLS & TECHNOLOGY CENTRE", "position": "ADMINISTRATIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:07:35.220252	2025-11-07 05:08:11.6699	effi.sstc@gmail.com	601131482206	effi nur shazleen binti salleh	\N
939	5a9ea998-99f0-4f31-9dd6-ec1e5972cac6	1	1	\N	Josareca	wjosareca@gmail.com	60107993874	t	2025-11-07 05:12:13.339199	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly Sabah", "position": "Tax Senior", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:11:50.804805	2025-11-07 05:12:13.339887	wjosareca@gmail.com	60107993874	josareca	\N
940	d5f0ee4e-9413-4a73-8f58-03652741e0f5	1	1	\N	Artha	arthanylla27@gmail.com	601125350031	t	2025-11-07 05:12:19.386532	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Nor", "position": "Marketing ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:12:01.58907	2025-11-07 05:12:19.387265	arthanylla27@gmail.com	601125350031	artha	\N
941	cd852f5d-09d1-4cd9-985e-22cbddbc58cb	1	1	\N	Allycia Joy Timothy	allycjj@gmail.com	60102710406	t	2025-11-07 05:12:34.177432	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "The North Borneo", "position": "Marketing ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:12:16.130394	2025-11-07 05:12:34.178018	allycjj@gmail.com	60102710406	allycia joy timothy	\N
942	6ddc2c35-defe-4780-8d86-7777ce4ad588	1	1	\N	Lenny Yap	Lenny.yyl@gamil.com	60194567297	t	2025-11-07 05:16:47.968859	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jasa tetap SB", "position": "Marketing manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:16:31.307773	2025-11-07 05:16:47.969442	lenny.yyl@gamil.com	60194567297	lenny yap	\N
944	baac1f59-d404-45aa-9fb7-4096468b5c25	1	1	\N	Alvis Loo	Alvis.jcim@gmail.com	60109479688	t	2025-11-07 05:17:33.851231	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "S3 Management", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:17:08.212121	2025-11-07 05:17:33.851807	alvis.jcim@gmail.com	60109479688	alvis loo	\N
972	1401312d-44dd-4044-9318-1bfe3b3716c5	1	1	\N	Mohammad Alif Abdulleh	alifitri2009@gmail.com	60197071907	t	2025-11-07 05:59:01.142708	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lados sdn bhd", "position": "Marketing manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:58:43.551403	2025-11-07 05:59:01.143396	alifitri2009@gmail.com	60197071907	mohammad alif abdulleh	\N
978	12868d44-b9da-4e31-b06b-f81bd04d8d9b	1	1	\N	Franciska Long	northborneohoney@gmail.com	60188749044	t	2025-11-07 06:05:49.940217	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "North Borneo Honey", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:04:57.398032	2025-11-07 06:05:49.940818	northborneohoney@gmail.com	60188749044	franciska long	\N
1000	1baeb934-2941-4d09-bf64-5c20996d45d3	1	1	\N	Mohamad Hamizan Bin Mozes	mijhamizan@gmail.com	601112692070	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University teknologi mara", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:27:15.695059	2025-11-07 06:27:15.695059	mijhamizan@gmail.com	601112692070	mohamad hamizan bin mozes	\N
1023	55b56d17-d487-4cd5-a41e-e8e454a50987	1	1	\N	Elriquez	havanaquezo@gmail.com	60168477500	t	2025-11-07 06:54:17.014074	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Gamuda Land ", "position": "Promoter ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:53:59.267154	2025-11-07 06:54:17.015527	havanaquezo@gmail.com	60168477500	elriquez	\N
1027	33677541-7479-4b25-a0c5-6f28665ec4a4	1	1	\N	Natasha Nabila	iamnatashanabila@gmail.com	60195812147	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Universiti Teknologi Mara (UiTM)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:54:36.811065	2025-11-07 06:54:36.811065	iamnatashanabila@gmail.com	60195812147	natasha nabila	\N
1121	c9382413-9628-4ac1-9d7a-4970a90a5004	1	3	\N	Andrew Wu Haw Jeng	\N	\N	t	2025-11-07 11:20:28.808748	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.505516	2025-11-07 11:20:28.809413	\N	\N	andrew wu haw jeng	\N
1291	5c305e2b-1216-47d2-b250-f98c9bae3d8b	1	3	\N	Lee Ya Ping	\N	61431197463	t	2025-11-08 01:03:05.587178	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Faith Contracting", "position": "Partner"}	2025-11-08 00:58:26.323049	2025-11-08 01:03:05.587863	\N	61431197463	lee ya ping	\N
1211	6ef236b1-f3da-4af6-a4d3-1742f2cac46f	1	11	\N	Robie Oryann Choo	bingbingrobiezz@gmail.com	60189613742	t	2025-11-08 00:23:51.303254	\N	1	1	\N	\N	\N	{"role": "Student", "company": "SMK PEKAN 2 KOTA BELUD "}	2025-11-07 23:26:47.665111	2025-11-08 00:23:51.303877	bingbingrobiezz@gmail.com	60189613742	robie oryann choo	\N
1220	9374f7df-0e9a-41d2-8b87-fdb0c8561bd8	1	1	\N	Beatrice Foo	beatrice.fbl@gmail.com	60198328893	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Persatuan Hainan", "position": "Asst. Treasurer"}	2025-11-08 00:22:54.329778	2025-11-08 00:22:54.329778	beatrice.fbl@gmail.com	60198328893	beatrice foo	\N
1221	79d81431-df35-4595-8d45-949d0178d2f7	1	3	\N	Kelvin Chang	\N	60189003873	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": "COO"}	2025-11-08 00:23:56.350832	2025-11-08 00:23:56.350832	\N	60189003873	kelvin chang	\N
1222	928d763c-8caa-4305-a623-010acb6b8a40	1	3	\N	Wah Khen Wu	\N	60189003873	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": "Director "}	2025-11-08 00:24:45.537113	2025-11-08 00:24:45.537113	\N	60189003873	wah khen wu	\N
1232	a26bd4fc-7ba4-40d3-acef-785be8460687	1	3	\N	Peggy Liow Vui Kun	\N	60128289908	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "LDP PARTY", "position": "INFRAS & UTILITY BUREAU CHIEF & SUPREME COUNCIL"}	2025-11-08 00:30:06.207333	2025-11-08 00:30:06.207333	\N	60128289908	peggy liow vui kun	\N
1233	80917a36-1caa-469b-878c-4de03f1c1455	1	1	\N	Xavier Wong Kwan	xavierwongkwan@gmail.com	60178205196	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "建国中学"}	2025-11-08 00:30:36.675004	2025-11-08 00:30:36.675004	xavierwongkwan@gmail.com	60178205196	xavier wong kwan	\N
1234	f01a4805-6624-4a85-8dab-d5ec347d7685	1	1	\N	Fung Sung Tze	22020@kiankok.edu.my	601161746533	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School"}	2025-11-08 00:31:07.054798	2025-11-08 00:32:14.927878	22020@kiankok.edu.my	601161746533	fung sung tze	\N
1231	6f329c1e-3913-40c0-8eb1-cb467a0b4190	1	3	\N	Kenneth Tang Yi Hau	\N	60138152558	t	2025-11-08 00:35:16.556198	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Japan Travel Bureau", "position": "Staff"}	2025-11-08 00:29:44.611799	2025-11-08 00:35:16.556874	\N	60138152558	kenneth tang yi hau	\N
1241	daf38140-f5c8-4778-83ec-17f611914043	1	3	\N	Yew Chee Hsing	\N	601121823433	t	2025-11-08 00:35:39.808803	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "YY RAINBOW ENTERPRISE ", "position": "Executive manager"}	2025-11-08 00:32:43.101209	2025-11-08 00:35:39.809306	\N	601121823433	yew chee hsing	\N
1240	25a4a647-bfa1-4fe8-b7a6-448f99357bc4	1	1	\N	Xavier Wong Kwan	xavierwongkwan@gmail.com	60178205196	t	2025-11-08 00:35:53.471273	\N	1	1	\N	\N	\N	{"role": "Student", "company": "建国中学"}	2025-11-08 00:32:26.25904	2025-11-08 00:35:53.471999	xavierwongkwan@gmail.com	60178205196	xavier wong kwan	\N
1126	a6de5685-adba-4d44-805e-7b6f67808347	1	3	\N	Aaron Chong Tsun Vui	\N	\N	t	2025-11-07 11:21:56.567111	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.533166	2025-11-07 11:21:56.567815	\N	\N	aaron chong tsun vui	\N
1129	8ab72204-23a3-4080-8ef3-0ff0e17d7a98	1	3	\N	Louise Yee Yan Shan	\N	\N	t	2025-11-07 11:22:49.438509	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.553777	2025-11-07 11:22:49.439133	\N	\N	louise yee yan shan	\N
1292	86bc75a5-9cd2-4b6c-80aa-2e6fd83650cf	1	3	\N	Lily Lee	\N	60143788981	t	2025-11-08 01:03:48.064443	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Petronas", "position": "Prod planner"}	2025-11-08 01:00:00.11502	2025-11-08 01:03:48.065044	\N	60143788981	lily lee	\N
1037	a94b64e6-b62e-4bbb-a374-28e7c4e5e3d6	1	1	\N	Muhammad Amjad Zakwan Bin Abu Hanipah	amjadzakwan5@gmail.com	60173155901	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIVERSITY MALAYSIA SABAH", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:04:36.7575	2025-11-07 07:04:36.7575	amjadzakwan5@gmail.com	60173155901	muhammad amjad zakwan bin abu hanipah	\N
1038	34abf1ca-4317-483a-ab36-1bd6d5a2ce69	1	1	\N	Ivan Yong	Ivanyong52633@gmail.com	60168813222	t	2025-11-07 07:06:23.939913	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "City Two Property Sdn Bhd ", "position": "Agent", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:05:59.988626	2025-11-07 07:06:23.940703	ivanyong52633@gmail.com	60168813222	ivan yong	\N
1041	9f84e855-de1e-4bcd-92b0-cc687cd1bba5	1	1	\N	Mohd Hirwan Bin Laidi	oneynna17@gmail.com	60198216020	t	2025-11-07 07:11:51.423999	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "CHILLSMOKED", "position": "OWNER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:11:31.095074	2025-11-07 07:11:51.425434	oneynna17@gmail.com	60198216020	mohd hirwan bin laidi	\N
1042	831833dc-0416-42b8-9bef-1bca675fbe96	1	1	\N	Hasrah Binti Malik	kerepek.sabah@gmail.com	601161794641	t	2025-11-07 07:15:45.290122	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Millionaire Industries Sdn Bhd ", "position": "Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:15:26.42946	2025-11-07 07:15:45.290927	kerepek.sabah@gmail.com	601161794641	hasrah binti malik	\N
1043	8f4a4333-0106-46a3-8363-57dcaddff663	1	1	\N	Lincoln	Isaac55king55@gmail.com	60138673586	t	2025-11-07 07:15:59.649985	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly Lsc Plt", "position": "Audit associates", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:15:32.790822	2025-11-07 07:15:59.650645	isaac55king55@gmail.com	60138673586	lincoln	\N
1044	dae2020d-28a3-45af-94d0-809838979813	1	1	\N	Dennylson	dennylsonprimus2304@gmail.com	60185962409	t	2025-11-07 07:16:30.348931	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "SCALEUP GROUP", "position": "ACCOUNT ASSOCIATE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:15:52.255537	2025-11-07 07:16:30.349574	dennylsonprimus2304@gmail.com	60185962409	dennylson	\N
1045	65112fa5-6a7d-46a3-8603-7824a554de5a	1	1	\N	Satinun Tambasal	satinun71@gmail.com	60133203525	t	2025-11-07 07:18:20.908311	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "King kong tech", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:18:03.867942	2025-11-07 07:18:20.909067	satinun71@gmail.com	60133203525	satinun tambasal	\N
1046	345b0479-43cf-4df7-a606-0f0682dea0c1	1	1	\N	Christine	christine.ponsoi@sedco.com.my	60138512485	t	2025-11-07 07:18:59.866882	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "SEDCO", "position": "BDI Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:18:14.860232	2025-11-07 07:18:59.867486	christine.ponsoi@sedco.com.my	60138512485	christine	\N
1047	e46d5c8e-f458-4868-b764-58930539805c	1	1	\N	Mutalib Uthman	abangmut@gmail.com	60172886620	t	2025-11-07 07:26:04.090063	29	1	1	\N	\N	\N	{"role": "VIP", "company": "MCMC", "position": "Officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:25:36.734551	2025-11-07 07:26:04.090751	abangmut@gmail.com	60172886620	mutalib uthman	\N
1048	a88c38e1-8059-471a-ad08-ae88ea6a8e25	1	1	\N	Shahrizal Denci	shahrizal@bantugroup.my	60122086090	t	2025-11-07 07:25:54.482806	29	1	1	\N	\N	\N	{"role": "VIP", "company": "Bantu Tani Sdn Bhd", "position": "director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:25:38.973655	2025-11-07 07:25:54.483517	shahrizal@bantugroup.my	60122086090	shahrizal denci	\N
1051	69009796-86e6-40ed-bf8f-9573d56458de	1	1	\N	Vivian Lee	vivianlsy.property@gmail.com	60179893287	t	2025-11-07 07:31:44.91463	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "CITY TWO PROPERTY SDN BHD", "position": "salesperson", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:31:21.525501	2025-11-07 07:31:44.915223	vivianlsy.property@gmail.com	60179893287	vivian lee	\N
1053	e625e0a6-9919-41e6-bd8d-2b7a64a2c05e	1	1	\N	Aqil	aqildzakwan32@gmail.com	601164137904	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Urban Farmer", "position": "Intern Student", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:32:43.802542	2025-11-07 07:32:43.802542	aqildzakwan32@gmail.com	601164137904	aqil	\N
1055	16510c1f-58b6-48ea-8ca3-9fd36c17ecd3	1	1	\N	Angel Lim	Mickko6460@gmail.com	60109826460	t	2025-11-07 07:37:25.541078	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Bukit bantayan ", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:36:24.957526	2025-11-07 07:37:25.541811	mickko6460@gmail.com	60109826460	angel lim	\N
1060	5d30a4d0-797d-4708-8a47-cec5c0ecc5dc	1	1	\N	Ken Ang	kenang2000@gmail.com	60198516888	t	2025-11-07 08:13:22.739001	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ang Systems Sdn Bhd", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:13:05.31524	2025-11-07 08:13:22.739652	kenang2000@gmail.com	60198516888	ken ang	\N
1061	d22c3c71-fa3d-40c7-9d31-be6dadaeac90	1	1	\N	Kb	mohdsyazwanjamaludin1988@gmail.com	60136102832	t	2025-11-07 08:19:15.218841	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BTC GROUP", "position": "Chef", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:18:25.904053	2025-11-07 08:19:15.219383	mohdsyazwanjamaludin1988@gmail.com	60136102832	kb	\N
1149	5bf7d059-9ba6-4e0c-be11-985f5436c2b6	1	3	\N	Connie Ting	\N	\N	t	2025-11-07 08:52:45.333	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Mundli Development (Sabah) Sb", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.70047	2025-11-07 11:28:39.112126	\N	\N	connie ting	\N
1197	55161c95-d188-4ac4-be05-b3c9264d03cb	1	3	\N	Aaron Chu	\N	\N	t	2025-11-07 11:30:48.972556	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": ""}	2025-11-07 11:28:08.634477	2025-11-07 11:30:48.973186	\N	\N	aaron chu	\N
1199	c1148090-940e-4765-89f0-467a4d339572	1	1	\N	Syafiq	kodaenk14@gmail.com	601151653436	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UITM"}	2025-11-07 11:31:27.609604	2025-11-07 11:31:27.609604	kodaenk14@gmail.com	601151653436	syafiq	\N
1223	7903fb18-4d71-4001-9f91-6469fb0683e9	1	3	\N	Sean Lim Hao	\N	60126890731	t	2025-11-08 00:29:53.902322	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "None", "position": "None"}	2025-11-08 00:25:09.180259	2025-11-08 00:29:53.902947	\N	60126890731	sean lim hao	\N
1200	1bfd039f-8f59-45c5-b298-e0b5a274704a	1	3	\N	Micheal Kiu	\N	\N	t	2025-11-07 11:34:07.097644	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": ""}	2025-11-07 11:32:39.21976	2025-11-07 11:34:07.098514	\N	\N	micheal kiu	\N
1208	c7db162f-fe96-4f5c-89c1-1ce039f8c667	1	11	\N	Cnoel Brindon	dynefie@gmail.com	60137141652	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SMK PEKAN II "}	2025-11-07 23:25:49.296655	2025-11-07 23:30:21.205684	dynefie@gmail.com	60137141652	cnoel brindon	\N
1209	cee1c003-3c8f-4de9-9209-7079d315b32e	1	11	\N	Dini Qistina Richard	dniqiss10@gmail.com	60189616840	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SMK PEKAN II KOTA BELUD"}	2025-11-07 23:26:10.934675	2025-11-07 23:30:57.316727	dniqiss10@gmail.com	60189616840	dini qistina richard	\N
1213	d020fca6-4a41-43ab-bada-39ae89fbe205	1	11	\N	Reina Christie Maikol	reina.christie.maikol@gmail.com	60103918050	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SMK PEKAN 2 KOTA BELUD"}	2025-11-07 23:27:59.198453	2025-11-07 23:31:09.174299	reina.christie.maikol@gmail.com	60103918050	reina christie maikol	\N
1212	8b23aae3-9e0f-4946-befe-ec27e71d411b	1	11	\N	Deniesia Sinius	dynefie@gmail.com	60164171652	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "Smk Pekan II"}	2025-11-07 23:27:10.88279	2025-11-07 23:31:16.110976	dynefie@gmail.com	60164171652	deniesia sinius	\N
1210	d5e2a901-a1ac-4e27-b978-17d588a46894	1	11	\N	Nadzuan	Nadz0_09@gmail.com	60146295244	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Smk pekan 2 kota belud"}	2025-11-07 23:26:25.743901	2025-11-07 23:31:28.533821	nadz0_09@gmail.com	60146295244	nadzuan	\N
1207	8cac2407-0067-49a6-bf37-64b151e20234	1	11	\N	Andrea Janis	andyra94@yahoo.com	601115204119	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "SMK PEKAN II KB"}	2025-11-07 23:25:34.556578	2025-11-07 23:31:41.745953	andyra94@yahoo.com	601115204119	andrea janis	\N
1226	1df15376-de0e-4295-81a6-ed8aab5ccd65	1	1	\N	Chia Chia	Chiac1717@gmail.com	60128286651	t	2025-11-08 00:25:58.818329	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Great Eastern life ", "position": "Agent"}	2025-11-08 00:25:34.457643	2025-11-08 00:25:58.81898	chiac1717@gmail.com	60128286651	chia chia	\N
1229	2e4356e7-4aa3-4fff-9ee2-faac0e223c43	1	1	\N	宛宸	W81286597@gmail.com	601151108269	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Yue Min penampang "}	2025-11-08 00:29:06.156669	2025-11-08 00:29:06.156669	w81286597@gmail.com	601151108269	宛宸	\N
1224	c0de1f25-fd9f-4913-abe3-3b95ee6fac66	1	3	\N	Chong Jing Yeng	\N	601165528271	t	2025-11-08 00:29:55.736051	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "-", "position": "-"}	2025-11-08 00:25:13.255782	2025-11-08 00:29:55.736925	\N	601165528271	chong jing yeng	\N
1225	ad124fd2-94ed-4df9-b706-ce509ffb8543	1	3	\N	Wong Ravend	\N	601116471717	t	2025-11-08 00:29:56.639862	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "-", "position": "-"}	2025-11-08 00:25:13.489621	2025-11-08 00:29:56.640446	\N	601116471717	wong ravend	\N
1227	ce25e013-7b38-498b-82e3-86f74f121682	1	3	\N	Thaddaeus Lee	\N	60146756888	t	2025-11-08 00:30:13.792329	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "-", "position": "-"}	2025-11-08 00:26:20.165375	2025-11-08 00:30:13.792896	\N	60146756888	thaddaeus lee	\N
1228	3bd0761e-7eec-4657-8ff2-c42475b2bb7b	1	1	\N	Yong Siew Tiew	Joyceyong.big@gmail.com	60164397293	t	2025-11-08 00:30:50.939725	\N	1	1	\N	\N	\N	{"role": "Student", "company": "Yue min penampang "}	2025-11-08 00:29:02.369787	2025-11-08 00:30:50.940381	joyceyong.big@gmail.com	60164397293	yong siew tiew	\N
1236	720ecfcc-cb88-49f7-a766-6b39e7804b3d	1	1	\N	Wong Chee Ming	cmwong@hotmail.com	60168306892	t	2025-11-08 00:32:10.223747	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sanctuary borneo travel Agency sdn bhd ", "position": "Manager"}	2025-11-08 00:31:49.174927	2025-11-08 00:32:10.22451	cmwong@hotmail.com	60168306892	wong chee ming	\N
1239	4a801250-595f-4779-84c7-21471b7747b9	1	1	\N	Ngoo Mee Qin	22001@kiankok.edu.my	601110610568	t	2025-11-08 00:32:37.676684	29	1	1	\N	\N	\N	{"role": "Student", "company": "Kian Kok Middlle School"}	2025-11-08 00:31:58.868516	2025-11-08 00:32:37.677266	22001@kiankok.edu.my	601110610568	ngoo mee qin	\N
1238	77e473dc-c709-4a90-bb06-da21a7cff912	1	1	\N	Vivian Choo	vivianchoo@kiankok.edu.my	60135463661	t	2025-11-08 00:33:35.676441	29	1	1	\N	\N	\N	{"role": "Lecturer", "company": "Kian Kok Middle School "}	2025-11-08 00:31:57.674709	2025-11-08 00:33:35.677158	vivianchoo@kiankok.edu.my	60135463661	vivian choo	\N
1230	5bde4870-880a-480c-823a-ca45dddbcdb8	1	3	\N	Khoo Szi Hui	\N	601126728067	t	2025-11-08 00:34:56.680755	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "EVER TOPWELL SDN BHD", "position": "COO"}	2025-11-08 00:29:36.052985	2025-11-08 00:34:56.681314	\N	601126728067	khoo szi hui	\N
1237	dc2fd6ae-b5a1-48a6-aedc-20eba9432285	1	3	\N	Chong Vun Yee	\N	601133037987	t	2025-11-08 00:34:58.767766	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "THE UNITED SABAH COMMUNITIES ASSOCIATION OF KK", "position": "Youth Leader"}	2025-11-08 00:31:53.476629	2025-11-08 00:34:58.768571	\N	601133037987	chong vun yee	\N
1242	493c5246-0f09-4f65-bf8a-a0aba7ce15ce	1	3	\N	Lau Yee Wen	\N	60138652863	t	2025-11-08 00:35:58.626687	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kwangsao ", "position": "Member"}	2025-11-08 00:33:12.743695	2025-11-08 00:35:58.627175	\N	60138652863	lau yee wen	\N
1250	6762e182-bad5-4cd7-8abf-81071f7e3fc1	1	1	\N	Michelle Chin	chinmenn@gmail.com	60168313386	t	2025-11-08 00:36:37.283218	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ge", "position": "Advisor"}	2025-11-08 00:35:55.807049	2025-11-08 00:36:37.283955	chinmenn@gmail.com	60168313386	michelle chin	\N
1243	be7d2b37-1c3b-4d8a-a412-8268c6de8c92	1	1	\N	Yantung	yanyanlau071219@gmail.com	601126191273	t	2025-11-08 00:37:19.914866	\N	1	1	\N	\N	\N	{"role": "Student", "company": "KIAN KOK MIDDLE SCHOOL"}	2025-11-08 00:33:36.210724	2025-11-08 00:37:19.915602	yanyanlau071219@gmail.com	601126191273	yantung	\N
1256	db087bc5-b036-46cf-b6c1-37d505baa994	1	1	\N	Maryam Binti Madzlan	maryambintimadzlan95@gmail.com	60109605005	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "MARYAM KSS ENTERPRISE", "position": "BISNES SENDIRI"}	2025-11-08 00:37:55.694909	2025-11-08 00:37:55.694909	maryambintimadzlan95@gmail.com	60109605005	maryam binti madzlan	\N
1251	31c83c24-f01a-4c2f-b527-0361a42b2f29	1	1	\N	Chin Siaw En	nickycse83@gmail.com	60178115110	t	2025-11-08 00:38:05.906337	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SY Lui Kim chock", "position": "IT SUPPORT "}	2025-11-08 00:36:03.446159	2025-11-08 00:38:05.907105	nickycse83@gmail.com	60178115110	chin siaw en	\N
1263	83ae8948-0f54-4a79-bc86-391232c61ddf	1	3	\N	Anthony Chong	\N	60168101755	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Moveon Production ", "position": "Business owner"}	2025-11-08 00:45:40.593626	2025-11-08 00:45:40.593626	\N	60168101755	anthony chong	\N
1264	ad95d95b-c26a-4b81-b913-7d9e1d63d839	1	3	\N	Micheal Kiu	\N	60167035967	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Agency", "position": "Leader"}	2025-11-08 00:45:59.771996	2025-11-08 00:45:59.771996	\N	60167035967	micheal kiu	\N
1297	cb1f4d09-f4eb-4895-a5a6-1209b6bc122b	1	3	\N	Tan Chun Long	\N	60125136198	t	2025-11-08 01:03:52.094903	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Natural Green House", "position": "IT Admin"}	2025-11-08 01:02:54.329021	2025-11-08 01:03:52.095443	\N	60125136198	tan chun long	\N
1064	345f14cd-fad6-4eee-bf8d-a05d46ac17d2	1	1	\N	Gan Bee Kim	beekim1016@gmail.com	60178868086	t	2025-11-07 08:37:56.005184	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "A", "position": "A", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:37:56.005184	2025-11-07 08:38:19.544039	beekim1016@gmail.com	60178868086	gan bee kim	\N
31	334ccfe9-5f4a-4b15-8c00-d3d65625bfda	1	2	\N	Egnes Binti Amat	\N	014-858 5390	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Dinamik Atlantik Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 06:42:30.509594	2025-11-06 17:44:01.413565	\N	0148585390	egnes binti amat	\N
35	7fa13a51-448f-4465-902c-02d3fafebb0f	1	2	\N	Jason Pan	\N	017-8190010	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Mega City Builder Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:04:28.129225	2025-11-06 17:22:16.531826	\N	0178190010	jason pan	\N
38	96261870-c59d-4624-9f0d-4edeee60e58e	1	2	\N	Siaw Ten Hon	\N	012-8285850	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hainan Properties Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:06:40.65113	2025-11-06 17:21:45.363392	\N	0128285850	siaw ten hon	\N
39	e1dca86d-2e4e-4e14-91e6-595c01fcdae8	1	2	\N	Johnnes	\N	60128857957	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Torr Energy", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:07:57.324527	2025-11-06 17:43:32.58629	\N	60128857957	johnnes	\N
42	923535d6-5a1d-4ad4-ae2c-b39ac09f4a3e	1	2	\N	Sudirman Mohd Alwi	\N	019-862 8924	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "MIDF", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:12:22.469711	2025-11-06 17:22:40.077638	\N	0198628924	sudirman mohd alwi	\N
45	29a71fa6-56a2-4d56-bfeb-580779e18a87	1	2	\N	Alvin Chong (no Need Print)	\N	010-9314768	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lemon Tree Ventures", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:19:09.330499	2025-11-06 17:34:04.777947	\N	0109314768	alvin chong (no need print)	\N
46	a73938dd-b16f-4694-869b-5b3f80a711ce	1	2	\N	Cheah	\N	016-5833333	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cheah BNI", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:19:51.114656	2025-11-06 17:44:04.232168	\N	0165833333	cheah	\N
48	5a12e3fc-a2b4-448f-a91c-c76c475f5897	1	2	\N	Thanawat	\N	012-4259010	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Jusprint", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:20:58.420572	2025-11-06 17:43:53.265651	\N	0124259010	thanawat	\N
50	60914dd5-baeb-4779-b9af-d79194c01909	1	2	\N	Mei Ling	\N	012-8337086	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Excellence Eco", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:22:26.671657	2025-11-06 17:23:39.42766	\N	0128337086	mei ling	\N
55	da69a04c-3b89-45b7-afd7-0f612bbef356	1	2	\N	Amarsali Bin Sandag	\N	010-9403474	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Amarli Enterprise (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:26:32.269611	2025-11-06 17:21:53.533889	\N	0109403474	amarsali bin sandag	\N
59	64ca8dec-e347-4d07-b1ea-b8a516e488d0	1	2	\N	Joanne Lo	\N	016-8102556	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "TAR UMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:28:26.402163	2025-11-06 17:24:38.617807	\N	0168102556	joanne lo	\N
68	d1b0dc7d-a0d1-4d33-a1a8-b0d9ff8a75ff	1	2	\N	Sariyaman Binti Sabur	\N	016-2298458	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "De'SR Resepi (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:43:30.233785	2025-11-06 17:24:45.050659	\N	0162298458	sariyaman binti sabur	\N
78	85a08809-f62f-434e-b77e-dafa86bd9c0c	1	2	\N	Leong Chan Fatt	\N	013-8869387	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Gamma Paradigm, Taiwan", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:35:00.965088	2025-11-06 17:39:51.194114	\N	0138869387	leong chan fatt	\N
81	8d342eb8-d703-4d1c-a60d-bb1cc8188226	1	2	\N	Hapsah Markati	\N	016-8378305	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Floresgam Sdn Bhd", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:36:32.706444	2025-11-06 17:22:21.782783	\N	0168378305	hapsah markati	\N
372	c58b9c42-618b-4ad0-b627-2679add29711	1	2	\N	Mitch	admin@remorph.digital	60193883994	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 08:47:55.504135	2025-11-06 17:32:54.815292	admin@remorph.digital	60193883994	mitch	\N
493	04524402-e4d4-4197-8222-b43cb2c72a22	1	1	\N	Stanleyster Polis (duplicate)	\N	60149151013	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Amazing Borneo", "position": "Senior Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.79696	2025-11-06 23:54:56.178589	\N	60149151013	stanleyster polis (duplicate)	\N
557	1889dcdc-83ae-4e86-b31c-1b8638771453	1	2	\N	Zurainah Morshid	\N	60168198351	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ina Legacy Sdn Bhd (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.551334	2025-11-06 17:27:03.766882	\N	60168198351	zurainah morshid	\N
559	db7622da-e14b-49fd-87c8-c04fc3110e00	1	2	\N	Lizah Bin Abdul Sani	\N	60197071907	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lados Sdn Bhd (F&B)", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.56694	2025-11-06 17:26:06.98084	\N	60197071907	lizah bin abdul sani	\N
562	b0364977-1933-4309-b28e-2db3ce5349b7	1	2	\N	Nurul Amyrah Nazwa Abdullah	\N	60189651051	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Munirah Niaga", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.590474	2025-11-06 17:27:16.75954	\N	60189651051	nurul amyrah nazwa abdullah	\N
1062	3a5b2762-add0-4fc2-aee1-fb5f4954ab65	1	1	\N	Ariq Anwar	ariqanwar06@gmail.con	60123065106	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "INTEC Education College", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:32:35.910321	2025-11-07 08:32:35.910321	ariqanwar06@gmail.con	60123065106	ariq anwar	\N
1063	807c24a4-dfdd-4687-ac36-e3b2b068aa6c	1	1	\N	Huzaifah Kamal	huzaifahmkamal@gmail.com	60167108043	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:32:51.89291	2025-11-07 08:32:51.89291	huzaifahmkamal@gmail.com	60167108043	huzaifah kamal	\N
568	5ac63e42-10b6-4714-89d7-e2d7ab8daf06	1	2	\N	Chin Shih Looi (f&b)	chinaloycia@gmail.com	60168396780	t	2025-11-06 23:48:53.017548	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lido Xiang Xiang Squid ", "position": "Stall Owner", "coupon_referral": "", "business_industry": "(F&B)", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.804537	2025-11-06 23:48:53.018224	chinaloycia@gmail.com	60168396780	chin shih looi (f&b)	\N
578	92bb9d63-4f9e-4852-9383-9e51c9bec518	1	2	\N	Patrick	\N	60168328116	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Axtrada", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:16.937953	2025-11-06 17:36:35.584427	\N	60168328116	patrick	\N
583	77872747-46cf-4ed1-a4bc-531579d40338	1	2	\N	Jason Lau	\N	60128276883	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Evergold", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.030892	2025-11-06 17:36:26.587426	\N	60128276883	jason lau	\N
587	88217e71-2157-47f1-b4c5-2734f331bedc	1	2	\N	Welter Kong	\N	60138747778	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "WSG Group", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.06305	2025-11-06 17:37:00.288541	\N	60138747778	welter kong	\N
592	5aec3eb0-adf9-4281-99b7-7d9cefe7c58a	1	2	\N	Pn Dahyana Edip	\N	60176329106	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Rimbunan Warisan", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.110474	2025-11-06 17:37:17.367691	\N	60176329106	pn dahyana edip	\N
596	230b2cb7-ef13-408d-af09-9a1c8acc12e4	1	2	\N	Sharie Naming	\N	60138728961	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Violet Inspire", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.147997	2025-11-06 17:37:28.277154	\N	60138728961	sharie naming	\N
601	80cf40fd-53bc-4fbf-a78b-edb4713b94de	1	2	\N	Ms Ruhayanti	\N	60168369486	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Puncak Billion", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.194468	2025-11-06 17:43:02.343186	\N	60168369486	ms ruhayanti	\N
606	41565108-af1e-4490-b82e-8ce317b124df	1	2	\N	Carmen Cheah	\N	60169490209	t	2025-11-07 00:31:32.951084	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Exabytes Network Sdn. Bhd.", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.296585	2025-11-07 00:31:32.951975	\N	60169490209	carmen cheah	\N
611	337c5c0e-0999-4c7b-91b7-b7c9c25e3f26	1	2	\N	Dona	\N	60128218007	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Dona Pearl", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.366304	2025-11-06 17:40:51.541582	\N	60128218007	dona	\N
621	b85d4109-9010-4f74-ac78-091087fd8f6d	1	2	\N	Zahirah	\N	60147225064	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Tenaga Sunnah Trading", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.465858	2025-11-06 17:43:23.254515	\N	60147225064	zahirah	\N
624	6b747ee2-4753-4394-9ca6-b8282e0d1aa0	1	1	\N	Wendy Ignatius	Wendy.Ignatius@sabah.gov.m	60168068818	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "{\\"flow_uid\\" => \\"69030ff14207e3a3b322397c\\", \\"flow_token\\" => \\"690c1ea5a9b3a548fd1cdc871762471347971\\", \\"screen_mq__name_2\\" => \\"Wendy Ignatius\\", \\"screen_mq__role_5\\" => \\"Delegate\\", \\"screen_mq__email_3\\" => \\"Wendy.Ignatius@sabah.gov.m\\", \\"screen_bhgbeaegagefc__position_4\\" => \\"Office Secretary\\", \\"screen_bhgbeaegagefc__company_name_3\\" => \\"Lembaga Kebudayaan Negeri Sabah\\", \\"screen_bhgbeaegagefc__ticket_number_2__then\\" => \\"CT243\\", \\"screen_bhgbeaegagefc__do_you_have_a_ticket_with_you_1\\" => \\"yes\\"}", "position": "{\\"flow_uid\\" => \\"69030ff14207e3a3b322397c\\", \\"flow_token\\" => \\"690c1ea5a9b3a548fd1cdc871762471347971\\", \\"screen_mq__name_2\\" => \\"Wendy Ignatius\\", \\"screen_mq__role_5\\" => \\"Delegate\\", \\"screen_mq__email_3\\" => \\"Wendy.Ignatius@sabah.gov.m\\", \\"screen_bhgbeaegagefc__position_4\\" => \\"Office Secretary\\", \\"screen_bhgbeaegagefc__company_name_3\\" => \\"Lembaga Kebudayaan Negeri Sabah\\", \\"screen_bhgbeaegagefc__ticket_number_2__then\\" => \\"CT243\\", \\"screen_bhgbeaegagefc__do_you_have_a_ticket_with_you_1\\" => \\"yes\\"}", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:24:31.171543	2025-11-06 23:24:31.171543	wendy.ignatius@sabah.gov.m	60168068818	wendy ignatius	\N
625	4c26dba8-374c-459a-9193-42ac490d95bc	1	1	\N	Wendy Ignatius	Wendy.Ignatius@sabah.gov.my	60168068818	t	2025-11-06 23:37:11.35903	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Office Secretary", "coupon_referral": "CT243", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:28:52.271286	2025-11-06 23:37:11.359783	wendy.ignatius@sabah.gov.my	60168068818	wendy ignatius	\N
628	65b94581-39ca-445e-b4c2-c71f6be89366	1	1	\N	Felicia Fung Fuei Kee	Feliciafung9531@yahoo.com	60192678662	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hong leong investment bank", "position": "Assistant manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:41:39.476372	2025-11-06 23:52:21.458266	feliciafung9531@yahoo.com	60192678662	felicia fung fuei kee	\N
631	2dfa21ad-9349-4903-ae02-657b07a1f8e4	1	1	\N	Aieron Lonsiong Ronnie	Aieron.LonsiongRonnie@sabah.gov.my	60138798849	t	2025-11-06 23:54:45.821249	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "Penolong Pegawai Teknologi maklumat", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:42:53.388553	2025-11-06 23:54:45.821975	aieron.lonsiongronnie@sabah.gov.my	60138798849	aieron lonsiong ronnie	\N
635	43a125be-2f27-4935-b946-896dcab6949b	1	1	\N	Hamidun Bin Jaharun	hamidunjaharun@gmail.com	601160527326	t	2025-11-06 23:54:14.006207	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "LEMBAGA KEBUDAYAAN NEGERI SABAH", "position": "INTERNAL AUDIT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:43:46.468536	2025-11-06 23:54:14.006911	hamidunjaharun@gmail.com	601160527326	hamidun bin jaharun	\N
650	1304dcad-6fea-4308-9be8-c31f246a1717	1	1	\N	Kent	ckmanagement19@gmail.com	601126892905	t	2025-11-06 23:55:56.317568	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "My drink trading Sdn Bhd ", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:52:14.464528	2025-11-06 23:55:56.31815	ckmanagement19@gmail.com	601126892905	kent	\N
656	ddaf4d92-691b-4ce6-9321-a31679acc5a8	1	1	\N	Abdul Qayyum Bin Abdul Karim	terajuborneo@gmail.com	60168034034	t	2025-11-06 23:59:57.442747	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "TERAJU BORNEO", "position": "PENGURUS", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:54:44.521013	2025-11-06 23:59:57.4433	terajuborneo@gmail.com	60168034034	abdul qayyum bin abdul karim	\N
658	880bc390-f935-4081-b606-15e6b4ddfcb4	1	1	\N	Yap Li Ling	Liling120@gmail.com	60128831038	t	2025-11-07 00:00:39.544533	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah Employer Association (SEA)", "position": "Secretary General", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:56:13.216881	2025-11-07 00:00:39.545333	liling120@gmail.com	60128831038	yap li ling	\N
659	25bf46c1-5f3b-4aaa-8d1f-8a5ada98f34a	1	1	\N	Simon Bin Sarong	simonsarong@gmail.com	60168148477	t	2025-11-06 23:57:11.1198	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Lembaga kebudayaan Negeri Sabah", "position": "Clerk", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:56:15.708914	2025-11-06 23:57:11.121343	simonsarong@gmail.com	60168148477	simon bin sarong	\N
664	79ee21b7-a65a-4106-9d43-b4ffcc61701b	1	1	\N	Rozharina Binti Rothman	Rozharina.Roth@sabah.gov.my	60168249277	t	2025-11-06 23:57:40.729381	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "LEMBAGA KEBUDAYAAN MEGERI SABAH", "position": "SECRETARY", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:00.818813	2025-11-06 23:57:40.730009	rozharina.roth@sabah.gov.my	60168249277	rozharina binti rothman	\N
667	eda42cd3-e751-4ff6-8a87-9da7bd5d056c	1	1	\N	Nurziya Muzzawer	nurziya@tarc.edu.my	60146552484	t	2025-11-07 00:06:08.459722	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TAR UMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:11.523718	2025-11-07 00:06:08.460503	nurziya@tarc.edu.my	60146552484	nurziya muzzawer	\N
669	ccb21d12-da09-4bba-94c5-fa9111cfd8e0	1	1	\N	Laila Binti Tahir	sassy_gurls86@yahoo.com	60127861803	t	2025-11-06 23:58:46.096885	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sabah cultural board ", "position": "Pegawai kebudayaan", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:42.625638	2025-11-06 23:58:46.097468	sassy_gurls86@yahoo.com	60127861803	laila binti tahir	\N
670	0e0e66e3-6a81-42f7-a0b8-b4c702126e16	1	1	\N	Rinah Linggom	rinahlinggom@gmail.com	60198400178	t	2025-11-06 23:58:59.299855	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Cultural Board ", "position": "Cultural Office ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:57:43.289837	2025-11-06 23:58:59.300593	rinahlinggom@gmail.com	60198400178	rinah linggom	\N
676	c0f05937-5e64-4fd5-9126-27e016798f8a	1	1	\N	Patricia G Kissol	patricigk@tarc.edu.my	60167762193	t	2025-11-07 00:06:54.107008	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TARUMT Sabah ", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:00:28.584544	2025-11-07 00:06:54.107619	patricigk@tarc.edu.my	60167762193	patricia g kissol	\N
680	6d76f288-e621-4a69-bd5b-4a02c7104064	1	1	\N	Lim Jia Zheng	limjz@tarc.edu.my	60168232166	t	2025-11-07 00:07:21.483861	\N	1	1	\N	\N	\N	{"role": "Lecturer", "company": "Tunku Abdul Rahman University of Management and Technology", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:25.673196	2025-11-07 00:07:21.484564	limjz@tarc.edu.my	60168232166	lim jia zheng	\N
684	83c28e0b-673c-44bb-8516-f293c7620045	1	1	\N	Said Ali Bin Said Idrus	Saidali4559t@gmail.com	60168247346	t	2025-11-07 00:11:08.727856	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Lembaga Kebudayaan Negeri Sabah ", "position": "Pegawai Kebudayaan ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:01:55.221837	2025-11-07 00:11:08.72867	saidali4559t@gmail.com	60168247346	said ali bin said idrus	\N
686	0cf79e9f-6112-4e0e-b5c0-80a6d5457e26	1	1	\N	Lim Chi Hing	asys_tech@yahoo.com	60198805867	t	2025-11-07 00:05:11.962975	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lim Scan Association", "position": "Treasurer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:02:11.448034	2025-11-07 00:05:11.963654	asys_tech@yahoo.com	60198805867	lim chi hing	\N
689	ae07e01c-70cf-4dc2-9dd8-4560284cec42	1	1	\N	Jenny Lim	jenny.mllim@gmail.com	60146929088	t	2025-11-07 00:03:47.848185	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Unit Pemimpin Pembangunan Masyarakat N19 Likas ", "position": "Pemaju Mukim ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:02:51.135876	2025-11-07 00:03:47.848747	jenny.mllim@gmail.com	60146929088	jenny lim	\N
694	706db275-02ce-4596-85e2-94e4a671bce6	1	1	\N	Judeth John Baptist	Judethjb@gmail.com	60138602088	t	2025-11-07 00:04:32.020983	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah segmen Association", "position": "President", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:04:10.148061	2025-11-07 00:04:32.021537	judethjb@gmail.com	60138602088	judeth john baptist	\N
697	39d90ed1-e3b3-433f-881e-7802c082d9eb	1	1	\N	Nelly Suiking	sales@srikom.com.my	60149988410	t	2025-11-07 00:06:01.646225	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Sri Komputer Sdn Bhd ", "position": "Senior Sales Executive ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:05:04.360133	2025-11-07 00:06:01.646969	sales@srikom.com.my	60149988410	nelly suiking	\N
699	dade509d-ea2e-4dbd-b714-248f6167fa7b	1	1	\N	Tan Yinglin	yl.tan@evo-point.com	60162398919	t	2025-11-07 00:11:45.82768	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Evopoint Sdn Bhd", "position": "Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:05:33.736424	2025-11-07 00:11:45.828539	yl.tan@evo-point.com	60162398919	tan yinglin	\N
702	16815271-2295-4d70-99be-a0d033d4ef04	1	1	\N	Lim Tiong Chin @ Harold	haroldlim86@yahoo.com	60138689999	t	2025-11-07 00:06:57.497268	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "TCTL RESOURCES", "position": "Sole Proprietor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:06:18.248938	2025-11-07 00:06:57.497932	haroldlim86@yahoo.com	60138689999	lim tiong chin @ harold	\N
660	ecb25967-3e0b-4778-a312-cbecffd612a6	1	1	\N	Kelvin Soimin	Kelvinmarzo@gmail.com	60109309965	t	2025-11-06 23:56:17.039101	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ilmu institute of learning", "position": "Markteting & Communications Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:56:17.039101	2025-11-06 23:58:23.705637	kelvinmarzo@gmail.com	60109309965	kelvin soimin	\N
709	411acbf9-0e8d-4933-b046-02b1a405b1e7	1	1	\N	Mohd Ali Bin Osman	pyeoali@gmail.com	60165886087	t	2025-11-07 00:09:46.779217	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BAYU ALISAH DESSERT", "position": "STAFF", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:07:50.384632	2025-11-12 01:16:58.737931	pyeoali@gmail.com	60165886087	mohd ali bin osman	\N
724	98559b29-f23e-4e69-a574-f1a2c7793f87	1	1	\N	Rachel Stanis Buandih	rachelstanisbuandih2@gmail.com	60198697232	t	2025-11-07 00:11:53.898131	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Researcher", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:04.982411	2025-11-07 00:11:53.899081	rachelstanisbuandih2@gmail.com	60198697232	rachel stanis buandih	\N
727	6bbc931a-39a4-48cc-b8e3-85f9079b4edb	1	1	\N	Arysha Fatin Fifieyana Binti Andres	aryshafatinfifieyana@gmail.com	60128342494	t	2025-11-07 00:14:56.433542	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "KEPKAS", "position": "FELO SMJ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:25.036522	2025-11-07 00:14:56.434139	aryshafatinfifieyana@gmail.com	60128342494	arysha fatin fifieyana binti andres	\N
739	fdbf99a9-2ecf-4631-a6bd-5fea51b08943	1	1	\N	Armah @ Faridah Bt Ahmad	armahfaridah67@gmail.com	60165829084	t	2025-11-07 02:31:28.042077	25	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "ARFA CATERING & baking", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:14:05.036181	2025-11-07 02:31:28.042708	armahfaridah67@gmail.com	60165829084	armah @ faridah bt ahmad	\N
746	5d30c0ee-570d-4f13-a366-a3d2fdf5ee2d	1	1	\N	𝖡𝗂𝖻𝗂𝖺𝗇𝖺 𝖡𝗍𝖾 𝖡𝖾𝗇𝗃𝖺𝗆𝗂𝗇	vycby783@gmail.com	601131598378	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "𝖡𝖯 𝖠𝗅𝗎𝗆𝗂𝗇𝗂𝗎𝗆 𝖤𝗑𝗍𝗋𝗎𝗌𝗂𝗈𝗇 𝖲𝖽𝗇.𝖡𝗁𝖽.", "position": "𝖯𝗋𝗈𝖽𝗎𝖼𝗍𝗂𝗈𝗇 𝖢𝗅𝖾𝗋𝗄", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:15:36.321394	2025-11-07 00:15:36.321394	vycby783@gmail.com	601131598378	𝖡𝗂𝖻𝗂𝖺𝗇𝖺 𝖡𝗍𝖾 𝖡𝖾𝗇𝗃𝖺𝗆𝗂𝗇	\N
756	3de1cd73-a23c-4266-b8a0-430152c29b60	1	1	\N	Hasnahwatie Abdul	hasnahwatie05@gmail.com	601126756296	t	2025-11-07 00:19:18.632033	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SEDCO", "position": "AUDIT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:18:11.934187	2025-11-12 01:39:37.991873	hasnahwatie05@gmail.com	601126756296	hasnahwatie abdul	\N
761	d5f6a5b1-c9d6-4f00-8a6b-4107dcd7168e	1	1	\N	Jason Teo	jasonteo@borneopac.my	60198504338	f	\N	\N	0	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Golden Elate Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:44.375784	2025-11-07 00:19:44.375784	jasonteo@borneopac.my	60198504338	jason teo	\N
767	8ccacae4-7052-4127-8909-f5a5658e144e	1	1	\N	Chai Hui Chet	\N	01161753725	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Paumin Hardware Sdn Bhd", "position": "Marketing", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:25:02.307523	2025-11-07 00:29:45.705543	\N	01161753725	chai hui chet	\N
785	d0b56154-7a66-4717-aa9f-59244deab360	1	1	\N	Joanne Lo Fui Senn	lofs@tarc.edu.my	60168102556	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "TAR UMT ", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:25:30.157837	2025-11-07 02:25:30.157837	lofs@tarc.edu.my	60168102556	joanne lo fui senn	\N
786	4ba590b4-da64-4218-a97f-bdf3b0797792	1	1	\N	Pang Vui Lee	pangvl@tarc.edu.my	60102321599	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "TARUMT", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:09.518795	2025-11-07 02:26:09.518795	pangvl@tarc.edu.my	60102321599	pang vui lee	\N
791	a170abc4-0935-4be7-9003-87206e0c41f3	1	1	\N	Dayang Siti Nurijam Rashilien Rasih	rashilien01@gmail.com	601131427654	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "great eastern", "position": "staff hq", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:43.689705	2025-11-07 02:26:43.689705	rashilien01@gmail.com	601131427654	dayang siti nurijam rashilien rasih	\N
792	1f03526d-2e57-4a80-9eae-2259f70017d3	1	1	\N	Juieqah Mat	chijuieqah@gmail.com	60136091967	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Great Eastern", "position": "Business Development Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:52.117157	2025-11-07 02:26:52.117157	chijuieqah@gmail.com	60136091967	juieqah mat	\N
793	420c81cf-fcbc-4955-b19a-59156bf225b9	1	1	\N	Ni Chen Chuen	chenchuen.ni@bakertilly.my	60163663815	t	2025-11-07 02:27:36.771029	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly LSC Tax Services Sdn Bhd", "position": "Tax director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:27:06.493105	2025-11-07 02:27:36.771972	chenchuen.ni@bakertilly.my	60163663815	ni chen chuen	\N
794	ca982989-a382-4f15-a91f-8d3a7199b482	1	1	\N	Alysha Phua Ke Xin	Alyshaphua@yahoo.com	6088363324	t	2025-11-07 02:31:46.046417	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Scaleup Corporate Services Sdn. Bhd.", "position": "Assistant Company Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:30:18.193373	2025-11-07 02:31:46.047129	alyshaphua@yahoo.com	6088363324	alysha phua ke xin	\N
776	58d63096-c226-4ae4-8fec-5307de87e184	1	1	\N	Yasimi Binti Masiang	\N	0128262844	t	2025-11-12 01:41:52.303913	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "RICHGREATS BORNEO", "position": "CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:40:26.734222	2025-11-12 01:41:52.304662	\N	0128262844	yasimi binti masiang	\N
1198	1b9f4fb0-fc2d-4e1a-b413-2de433cfd518	1	3	\N	Voca Kun	\N	\N	t	2025-11-07 11:30:20.827985	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jesselton Property", "position": ""}	2025-11-07 11:28:15.030074	2025-11-07 11:30:20.828887	\N	\N	voca kun	\N
799	1c4dab91-22f3-4237-929e-60c197c35807	1	1	\N	Doreen Binti Moliun	doreenmedward@gmail.com	60189612085	t	2025-11-07 02:38:19.797091	24	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "AZ DOREEN ", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:37:34.552904	2025-11-07 02:38:19.797858	doreenmedward@gmail.com	60189612085	doreen binti moliun	\N
801	26160efc-145e-4b41-a2f2-edcf1735d5a9	1	1	\N	Nurazrina Binti Azah	chenta.amoi.chantek@gmail.com	60143548878	t	2025-11-07 02:39:45.361332	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "mide", "position": "penolong pegawai tadbir", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:38:11.18778	2025-11-07 02:39:45.362071	chenta.amoi.chantek@gmail.com	60143548878	nurazrina binti azah	\N
802	c74450cc-c9d2-42b7-b208-be05a494b6eb	1	1	\N	Sharmine Chia	sharmine.chia98@gmail.com	60168268117	t	2025-11-07 02:40:09.73812	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "L.S.Chin, Sharmine Chia & Partners", "position": "Partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:38:56.03483	2025-11-07 02:40:09.738785	sharmine.chia98@gmail.com	60168268117	sharmine chia	\N
804	ff677eb4-afb7-4c43-93dc-fa6a48bb6757	1	1	\N	Isabel Lo	isabel.urbanfarmer@gmail.com	60123788930	t	2025-11-07 02:40:43.400784	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Urban Homefarming Sdn Bhd", "position": "COO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:40:00.282164	2025-11-07 02:40:43.401343	isabel.urbanfarmer@gmail.com	60123788930	isabel lo	\N
806	db883a49-2ada-4cba-bad2-adc32408c4e9	1	1	\N	Annah Pahaluddin	Annahpahaluddin@gmail.com	60128661563	t	2025-11-07 03:26:58.039678	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan profesional suluk", "position": "Member", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:40:48.853458	2025-11-07 03:26:58.040216	annahpahaluddin@gmail.com	60128661563	annah pahaluddin	\N
811	d80a69e5-98d7-4370-a0ff-8705d44380df	1	1	\N	Nurul Diyana Mohd Azid	nuruldiyanamohdazid@gmail.com	60128182203	t	2025-11-07 02:48:21.8584	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Agrobis Integrated Trading", "position": "Managing Partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:46:49.779513	2025-11-07 02:48:21.859244	nuruldiyanamohdazid@gmail.com	60128182203	nurul diyana mohd azid	\N
823	af20deea-8e75-4e38-88a1-5f6ab47686e4	1	1	\N	Ervina Chong	ervinachong99@gmail.com	60199965530	t	2025-11-07 03:01:27.298263	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ipsos Sdn Bhd", "position": "Interviewer ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:00:54.227972	2025-11-07 03:01:27.298995	ervinachong99@gmail.com	60199965530	ervina chong	\N
829	a0ab5ff1-aa6a-40f6-9bdd-cf9f5a38685a	1	1	\N	Nurul Amyrah Nazwa Abdullah	amymunirah81@gmail.com	60102704188	t	2025-11-07 03:04:32.13975	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "munirah niaga", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:02:48.084506	2025-11-07 03:04:32.140297	amymunirah81@gmail.com	60102704188	nurul amyrah nazwa abdullah	\N
831	d04f920b-552c-41ec-85d3-223f2a6036b5	1	1	\N	Nurul Azirah	nurulazirah0799@gmail.com	60138631974	t	2025-11-07 03:23:53.870182	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BTC Maju Holding Sdn Bhd", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:03:24.617528	2025-11-07 03:23:53.870723	nurulazirah0799@gmail.com	60138631974	nurul azirah	\N
836	aa4dd9f6-7635-4b1e-a015-b9ef458e0e4e	1	1	\N	Dg Khairunnisa Ag Ibrahim	nisakojai8386@gmail.com	601153241993	t	2025-11-07 03:10:15.560727	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "JPPM SABAH", "position": "Executive officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:07:35.459733	2025-11-07 03:10:15.56137	nisakojai8386@gmail.com	601153241993	dg khairunnisa ag ibrahim	\N
837	f93af013-b2f0-4a8f-9e32-6beb9b9866c1	1	1	\N	Dewi Binti Maing	wiwietasha@gmail.com	60168363083	t	2025-11-07 03:10:12.413537	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "JPPM", "position": "executive officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:07:47.775958	2025-11-07 03:10:12.414236	wiwietasha@gmail.com	60168363083	dewi binti maing	\N
839	bfcd5a8e-e1a0-4dfa-ba05-099e921bbdd9	1	1	\N	Elvin Chin	Elvinchin94@gmail.com	60196041352	t	2025-11-07 03:09:54.221988	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ripoff printism", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:09:33.250926	2025-11-07 03:09:54.222656	elvinchin94@gmail.com	60196041352	elvin chin	\N
845	ee885e00-8bc9-4215-9480-7eaccd4bc212	1	1	\N	Muhammad Haikal Sukardi	Suparsukardi90@gmaill.com	60168058725	t	2025-11-07 03:12:41.522813	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Btc maju holding sdn.bhd (btcfoods)", "position": "Sales", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:12:14.447028	2025-11-07 03:12:41.523728	suparsukardi90@gmaill.com	60168058725	muhammad haikal sukardi	\N
857	33c31c08-7261-4249-8f90-023391738aca	1	1	\N	Chiew Cheng Yi	chiewccy1@gmail.com	60142704730	t	2025-11-07 03:17:48.295981	29	1	1	\N	\N	\N	{"role": "Student", "company": "Universiti Malaysia Sabah", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:16:44.790332	2025-11-07 03:17:48.296666	chiewccy1@gmail.com	60142704730	chiew cheng yi	\N
860	43d115a6-c4ea-4a55-a50f-45e133a264d8	1	1	\N	Mohd Fazil Ajak	berjiriajutagroup@gmail.com	60162954523	t	2025-11-07 03:19:03.567047	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "PERTUBUHAN PROFESIONAL SULUK SABAH", "position": "PRESIDENT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:18:46.341303	2025-11-07 03:19:03.56773	berjiriajutagroup@gmail.com	60162954523	mohd fazil ajak	\N
866	bf175538-f525-43b7-b99b-8621d439ae07	1	1	\N	Dr Bamini Kpd Balakrishnan	bamini@ums.edu.my	601151113234	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "Centre for Innovation and commercialisation management ", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:27:21.464977	2025-11-07 03:27:21.464977	bamini@ums.edu.my	601151113234	dr bamini kpd balakrishnan	\N
803	3cae1dec-9d14-4e71-9dfc-0446ef04c0b8	1	1	\N	Nuridah Binti Sallih	nuridahnuridahera@gmail.com	601121763161	t	2025-11-07 02:42:32.704756	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Harmoni Etnik Nabawan Sabah ", "position": "President"}	2025-11-07 02:39:45.843149	2025-11-11 06:40:40.931126	nuridahnuridahera@gmail.com	601121763161	nuridah binti sallih	\N
849	a70a1ccc-5b49-4735-92b2-2a92bc224264	1	1	\N	Chang Kok Kien	Kent.scc@gmail.com	60168405000	t	2025-11-07 03:13:54.382607	29	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH CREDIT CORPORATION", "position": "HEAD OF CREDIT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:13:35.730372	2025-11-12 00:36:40.10281	kent.scc@gmail.com	60168405000	chang kok kien	\N
828	7b90aa46-6e78-4ed2-a705-8df91608c4ed	1	1	\N	Melvin Mau Chi Chiin	melvinmaucc@gmail.com	60143720936	t	2025-11-07 03:02:36.695046	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mitsubishu eon Auto mart", "position": "Salesman", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:02:36.695046	2025-11-07 03:03:09.808253	melvinmaucc@gmail.com	60143720936	melvin mau chi chiin	\N
871	3d9c681e-97e9-4788-a9fb-f44b6fdcd1c8	1	1	\N	Azlina Sahiron	miminurhidaeddie@gmail.com	60128661563	t	2025-11-07 03:34:05.997063	29	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Berjiria Juta Group ", "position": "Menager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:31:53.156275	2025-11-07 03:34:05.997729	miminurhidaeddie@gmail.com	60128661563	azlina sahiron	\N
873	9f20bd42-be5a-43e0-a821-77217b9b0e23	1	1	\N	Erick Jerret Baeren	erickjerret94@gmail.com	601135353828	t	2025-11-07 03:35:44.818715	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "CMA Group", "position": "Marketing Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:35:16.696722	2025-11-07 03:35:44.81949	erickjerret94@gmail.com	601135353828	erick jerret baeren	\N
877	5d1a7271-2b6b-4fd1-9ae4-76c6d5b4eafc	1	1	\N	Lim Lee Fun	Richardpan@1954gmial.com	601157804449	t	2025-11-07 03:42:35.393226	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "-", "position": " -", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:42:15.808096	2025-11-07 03:42:35.39381	richardpan@1954gmial.com	601157804449	lim lee fun	\N
881	33ebdeee-e28b-4c7d-b4c5-8f1820c49fbb	1	1	\N	Naratha Bt Dimis @ Nur Asyikin	Naratha.dimis@sabah.gov.my	60107793349	t	2025-11-07 03:49:59.922699	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kementerian Pelancongan, Kebudayaan & Alam Sekitar", "position": "Penolong Pegawai Teknologi Maklumat", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:49:35.356833	2025-11-07 03:49:59.923451	naratha.dimis@sabah.gov.my	60107793349	naratha bt dimis @ nur asyikin	\N
888	6911c224-a9d9-40c9-bc79-f6812d50a937	1	1	\N	Isabella Rachel Dawat	dawatradang81@gmail.com	60177723037	t	2025-11-07 03:56:48.279467	30	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hainan cafe", "position": "Promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:56:19.26507	2025-11-07 03:56:48.280068	dawatradang81@gmail.com	60177723037	isabella rachel dawat	\N
891	6d9dcafc-8edd-4406-aae5-f2074d4e43d3	1	1	\N	Celestina Kouju	Ckouju_73@yahoo.com	60168277988	t	2025-11-07 03:59:42.767589	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ipsos sdn bhd", "position": "Field exacutive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:59:15.104869	2025-11-07 03:59:42.768243	ckouju_73@yahoo.com	60168277988	celestina kouju	\N
892	a696d4a9-f241-42f6-9384-4bd72bd8509d	1	1	\N	Jemmi Sagun	Batzoriginz84@gmail.com	60107707179	t	2025-11-07 04:00:05.713586	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ipsos sdn bhd", "position": "Survey officer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:59:28.197951	2025-11-07 04:00:05.717043	batzoriginz84@gmail.com	60107707179	jemmi sagun	\N
896	2f393334-42c4-435e-8a3a-40c1ef10d86b	1	1	\N	Jerome Tew Jun Xiong	Jerometew95@gmail.com	60174860902	t	2025-11-07 04:02:09.448535	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Unique Dental ", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:01:47.738309	2025-11-07 04:02:09.449142	jerometew95@gmail.com	60174860902	jerome tew jun xiong	\N
900	3e3e0a0c-867d-4da2-a311-a12d2711b162	1	1	\N	Wendy	zoeylee69@hotmail.com	60138183779	t	2025-11-07 04:12:37.681063	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Maybank", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:12:04.807612	2025-11-07 04:12:37.68169	zoeylee69@hotmail.com	60138183779	wendy	\N
903	0d4f5906-d077-4261-a179-2d4bb322b0eb	1	1	\N	Noremma Jamil	noremmajamil@yahoo.com	60165880477	t	2025-11-07 04:17:08.47333	29	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "SALES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:16:47.209209	2025-11-07 04:17:08.474091	noremmajamil@yahoo.com	60165880477	noremma jamil	\N
907	afafcb7e-27fe-4715-a284-6c6e834290f4	1	1	\N	Yeong Kok Wah	Wah_kendy@gmail.com	60128290380	t	2025-11-07 04:22:17.503012	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Nepco Marketing sdn bhd ", "position": "Boss", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:21:59.880528	2025-11-07 04:22:17.504496	wah_kendy@gmail.com	60128290380	yeong kok wah	\N
912	114fa210-82e3-48da-b4f9-ce05821e0518	1	1	\N	Mildred	Mildredshantia@gmail.com	60124330936	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Holiday inn express kota kinabalu", "position": "Assistant sales manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:31:21.952105	2025-11-07 04:31:21.952105	mildredshantia@gmail.com	60124330936	mildred	\N
916	16c216c2-612b-4f7d-850f-4d81fb681d77	1	1	\N	Kathrie Rubil	kathrierubil@gmail.com	60143875652	t	2025-11-07 04:36:39.793134	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "Shakes World Sdn Bhd", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:35:16.14482	2025-11-07 04:36:39.793865	kathrierubil@gmail.com	60143875652	kathrie rubil	\N
922	e8a0a082-a4ac-4ad6-826b-8c3d362acd09	1	1	\N	Bryan	support@angsystems.com	60197318778	t	2025-11-07 04:50:26.038104	30	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Ang systems sdn bhd", "position": "Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:49:51.441839	2025-11-07 04:50:26.038933	support@angsystems.com	60197318778	bryan	\N
926	a269b068-8cca-45e0-8517-ce58dbe4644f	1	1	\N	Elaine	han10.elaine@gmail.com	60165522380	t	2025-11-07 04:53:14.141475	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Yhp Event Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:52:43.471579	2025-11-07 04:53:14.142055	han10.elaine@gmail.com	60165522380	elaine	\N
928	891c2420-8d5c-4b45-bd53-b9b2e38847d0	1	1	\N	Hanis	cikhanisyu12@gmail.com	601111039946	t	2025-11-07 04:58:54.104934	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cinnamonkins ", "position": "Marketing ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:55:39.889299	2025-11-07 04:58:54.105688	cikhanisyu12@gmail.com	601111039946	hanis	\N
933	149e526f-3193-4222-a8e0-4a197be720ca	1	1	\N	Sarmini Sarman	Sharminesarman@gmail.com	60145720901	t	2025-11-07 05:03:08.851959	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sharmaine Cosmetic ", "position": "Pengurus", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:01:48.108043	2025-11-07 05:03:08.85256	sharminesarman@gmail.com	60145720901	sarmini sarman	\N
937	3b14ec2e-ce8b-486a-ba5b-697e8a743d60	1	1	\N	Flory Victoria Matius	flory.sstc@gmail.com	601112075736	t	2025-11-07 05:07:43.08263	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Skills & Technology Centre", "position": "Administrative", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:07:16.734094	2025-11-07 05:07:43.083169	flory.sstc@gmail.com	601112075736	flory victoria matius	\N
943	6ac5f852-f5d6-4a85-9dd4-dc5e337b7880	1	1	\N	Brenda Lo Chia Wen	bgriseldxx22@gmail.com	60107993874	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "G&A ", "position": "Tax Junior", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:17:02.557865	2025-11-07 05:17:02.557865	bgriseldxx22@gmail.com	60107993874	brenda lo chia wen	\N
945	eccd5f0d-e235-403a-8acd-e82f87207a21	1	1	\N	Erna Surayati Matussin	ernasurayati21@gmail.com	60168113608	t	2025-11-07 05:19:32.722393	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "JHEWA", "position": "promoter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:19:13.410708	2025-11-07 05:19:32.722933	ernasurayati21@gmail.com	60168113608	erna surayati matussin	\N
954	9663c60a-de9c-45f5-9e89-aaca15ebcb1b	1	1	\N	Alicia	aliciapy817@gmail.com	60168069522	f	\N	\N	0	1	\N	\N	\N	{"role": "Option 6", "company": "United Movers Sdn Bhd", "position": "Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:24:25.723209	2025-11-07 05:24:25.723209	aliciapy817@gmail.com	60168069522	alicia	\N
958	fa243b2e-9742-454d-9911-037d71fa558f	1	1	\N	Connie	connietsy77@gmail.com	60198600823	f	\N	\N	0	1	\N	\N	\N	{"role": "Option 6", "company": "-", "position": "-", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:27:27.094981	2025-11-07 05:27:27.094981	connietsy77@gmail.com	60198600823	connie	\N
961	2b8dfb53-eec5-4765-9468-910b16727ae6	1	1	\N	Nor Farah Ainie Binti Jiran @ Jirun	norfarahainie07@gmail.com	60109472454	t	2025-11-07 05:31:51.612987	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "BAKER TILLY SABAH", "position": "ACCOUNT ASSOCIATE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:31:32.776293	2025-11-07 05:31:51.613724	norfarahainie07@gmail.com	60109472454	nor farah ainie binti jiran @ jirun	\N
980	992647b5-8214-4c17-8732-5efb0eecd139	1	1	\N	Jason Tai	jasontai@uniang.com	60178028088	t	2025-11-07 06:05:58.862227	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "UNIANG PLASTIC INDUSTRIES SDN BHD", "position": "Sales Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:05:41.21848	2025-11-07 06:05:58.862885	jasontai@uniang.com	60178028088	jason tai	\N
982	68c76e7a-4cbe-4ece-a086-16f0aa1c5dab	1	1	\N	Nabil Rayyan	nabilshahnaz05@gmail.com	60197207021	t	2025-11-07 06:08:36.327746	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "UrbanFarmer", "position": "intern", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:08:14.760327	2025-11-07 06:08:36.328473	nabilshahnaz05@gmail.com	60197207021	nabil rayyan	\N
990	1403c074-a228-42c7-a3f4-346af35c1730	1	1	\N	Muhammad Akasyah Bin Azizie	mdakasyah42@gmail.com	601163393921	t	2025-11-07 06:19:41.515404	26	1	1	\N	\N	\N	{"role": "Student", "company": "Universiti Teknologi MARA", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:19:19.65742	2025-11-07 06:19:41.516066	mdakasyah42@gmail.com	601163393921	muhammad akasyah bin azizie	\N
994	11a22d8b-713e-4430-ba92-7f7c5d66f6ab	1	1	\N	Siti Nurhazirah Harun	ziraharun03@gmail.com	601160934181	t	2025-11-07 06:20:08.467409	26	1	1	\N	\N	\N	{"role": "Student", "company": "UNIVERSITY TECHNOLOGY MARA", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:19:49.46163	2025-11-07 06:20:08.468021	ziraharun03@gmail.com	601160934181	siti nurhazirah harun	\N
1013	72d86983-ed5b-459d-9d73-29d37ed2c119	1	1	\N	Rustam Bin Ahmad	inquires@soundstecheng.com	60138970988	t	2025-11-07 06:48:09.912296	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Sounds tech Production", "position": "SALES AND MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:47:23.992314	2025-11-07 06:48:09.913046	inquires@soundstecheng.com	60138970988	rustam bin ahmad	\N
996	39ea27fe-2c41-47c7-88cd-0ccfb986954f	1	1	\N	Wong Siew Wan	wong.sw@midf.com.my	60168031970	t	2025-11-12 01:18:38.31349	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MIDF", "position": "RELATIONSHIP MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:25:11.10227	2025-11-12 01:18:38.314124	wong.sw@midf.com.my	60168031970	wong siew wan	\N
1101	1047cc5f-75c0-4639-9ed4-13670ec76718	1	3	\N	Wong Kee Haw	\N	\N	t	2025-11-12 01:20:08.980783	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "HAINAN ASSOCIATION KOTA KINABALU", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.323101	2025-11-12 01:20:08.981519	\N	\N	wong kee haw	\N
977	9b3e6b32-446a-4da7-b7fd-7c998f0e9d4a	1	1	\N	Daneil Chan	Everich.kk@gmail.com	60127830329	t	2025-11-07 06:04:43.375397	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Everich ventures sdn bhd", "position": "Business development ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:04:43.375397	2025-11-07 06:05:37.831578	everich.kk@gmail.com	60127830329	daneil chan	\N
1010	a52f71e1-7108-4fcf-9de4-f5396854ee63	1	1	\N	Poong Ka Tsun	katsun@reviewbah.com	60168311718	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "REVIEWBAH", "position": "CTO / TECH LEAD", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:42:05.54922	2025-11-11 08:18:58.329128	katsun@reviewbah.com	60168311718	poong ka tsun	\N
1068	2fcbe7ed-264c-4103-a138-c69b7d7edf49	1	3	\N	Adeline Chong	\N	\N	t	2025-11-07 09:40:38.754825	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.051227	2025-11-07 09:40:38.755447	\N	\N	adeline chong	\N
1066	01cf6be0-9188-4507-8101-d8ff744e6828	1	3	\N	Arthur Lee	\N	\N	t	2025-11-07 11:44:12.833622	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.03487	2025-11-07 11:44:12.834165	\N	\N	arthur lee	\N
1069	683c4f71-ecf5-472f-ad71-61a6696ccd2a	1	3	\N	Jasper Ng	\N	\N	t	2025-11-07 11:44:24.293997	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.061053	2025-11-07 11:44:24.294862	\N	\N	jasper ng	\N
1070	5ac8460d-b9e6-4b66-888e-a6af103a61cd	1	3	\N	Tai Thau Bin	\N	\N	t	2025-11-07 09:49:28.361491	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.069421	2025-11-07 09:49:28.362678	\N	\N	tai thau bin	\N
1071	afd2da24-b152-4668-be5a-53c46c0cf10d	1	3	\N	Cindy Han	\N	\N	t	2025-11-07 09:48:53.85346	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.078107	2025-11-07 09:48:53.854122	\N	\N	cindy han	\N
1067	3b049397-3828-4e84-aae5-a2b3326eb53b	1	3	\N	Roger Lo	\N	\N	t	2025-11-07 11:44:31.026934	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.043565	2025-11-07 11:44:31.027539	\N	\N	roger lo	\N
1203	f5c79a25-ee20-44e7-8706-3c697acfde03	1	1	\N	Edina Edimisa	eaadina21@gmail.com	60147806654	t	2025-11-07 12:15:04.44178	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Berjiria Juta Group", "position": "Manager"}	2025-11-07 12:09:34.636726	2025-11-07 12:15:04.44242	eaadina21@gmail.com	60147806654	edina edimisa	\N
1301	9d03c468-7b5b-4e0f-87eb-e791b35020a8	1	1	\N	Simon Jr Jalin	Simon@jalincreative.com	60198630556	t	2025-11-08 01:04:47.499228	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jalin creative", "position": "CEO"}	2025-11-08 01:04:29.520598	2025-11-08 01:04:47.499918	simon@jalincreative.com	60198630556	simon jr jalin	\N
1296	aafa3a15-7abe-4ab8-8a5d-530f3dbcdaa2	1	1	\N	Conzes Lee	conzes252@gmail.com	60105476331	t	2025-11-08 01:04:54.245028	\N	1	1	\N	\N	\N	{"role": "Student", "company": "SABAH "}	2025-11-08 01:02:18.077168	2025-11-08 01:04:54.245757	conzes252@gmail.com	60105476331	conzes lee	\N
1299	a77d9e60-600b-430c-aedb-c45334dc92e3	1	1	\N	Jason	mamboo2232@outlook.com	60127853528	t	2025-11-08 01:05:14.084407	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "SRI MAJU ENTERPRISE", "position": "SALESMAN"}	2025-11-08 01:04:07.166249	2025-11-08 01:05:14.084974	mamboo2232@outlook.com	60127853528	jason	\N
1302	e846a58b-4c24-42a5-b68e-2e60c2770cc8	1	1	\N	Ayeen Khnin	ayeenasyuraa@gmail.com	601151321935	t	2025-11-08 01:05:26.967253	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jalin Creative Sdn. Bhd. ", "position": "Admin"}	2025-11-08 01:04:32.381502	2025-11-08 01:05:26.968055	ayeenasyuraa@gmail.com	601151321935	ayeen khnin	\N
1303	462b24a7-0262-4708-aea0-4d480f763242	1	1	\N	Muhammad Shameer Bin Sawar	muhammadshameersawar@gmail.com	60128639330	t	2025-11-08 01:05:49.107545	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jalin Creative ", "position": "STE"}	2025-11-08 01:04:36.807156	2025-11-08 01:05:49.108101	muhammadshameersawar@gmail.com	60128639330	muhammad shameer bin sawar	\N
1298	b540a4e5-c08c-4c09-bd5d-590f3fb8b722	1	3	\N	Monica Chung	\N	60168810091	t	2025-11-08 01:06:20.593569	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "N/ A ", "position": "N/A "}	2025-11-08 01:04:03.277791	2025-11-08 01:06:20.594091	\N	60168810091	monica chung	\N
1304	e72403fa-50da-4d94-8f17-84ece9fae397	1	1	\N	Chester Junus	chester.avenger@gmail.com	60178686535	t	2025-11-08 01:06:25.769757	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jalin Creative SDN BHD", "position": "VR Content Creator cum. Photographer "}	2025-11-08 01:04:49.369678	2025-11-08 01:06:25.770457	chester.avenger@gmail.com	60178686535	chester junus	\N
1087	a556f71a-6626-4696-b70c-a0a2d41e3eca	1	3	\N	Ps Dr Irene Choon	\N	\N	t	2025-11-07 10:56:57.918072	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.2008	2025-11-07 10:56:57.918742	\N	\N	ps dr irene choon	\N
1089	655b630d-e41e-43e9-b41e-384b49c88987	1	3	\N	Ruth Kok	\N	\N	t	2025-11-07 10:57:37.095755	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.212413	2025-11-07 10:57:37.096385	\N	\N	ruth kok	\N
1074	63f77fa9-e27e-497d-bb82-20dceb0f4b27	1	3	\N	Kenny Lo	\N	\N	t	\N	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.100291	2025-11-07 09:53:23.200837	\N	\N	kenny lo	\N
1088	c3616490-c711-4ee3-8fa9-a90ac69d55fd	1	3	\N	Rev Luke Chong	\N	\N	t	2025-11-07 10:57:41.765656	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.207022	2025-11-07 10:57:41.766581	\N	\N	rev luke chong	\N
1092	86ebbb57-8494-4a05-994c-8b87b4af35d3	1	3	\N	Michael Chong	\N	\N	t	2025-11-07 10:58:19.39247	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.241145	2025-11-07 10:58:19.393307	\N	\N	michael chong	\N
1073	6b74c1a6-32cc-4a50-bc8d-f52dfba4d473	1	3	\N	Jason Yong	\N	\N	t	2025-11-07 10:54:22.9922	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.091497	2025-11-07 10:54:22.993037	\N	\N	jason yong	\N
1075	f8afa1cb-a7fb-4f3f-9632-d3b28e5088bb	1	3	\N	Victoria Ng	\N	\N	t	2025-11-07 10:55:01.269316	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.10811	2025-11-07 10:55:01.270152	\N	\N	victoria ng	\N
1077	17255ba9-cc41-4dfd-8f7c-a79e20fb8ddd	1	3	\N	Daniel Chang	\N	\N	t	2025-11-07 10:55:01.926498	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.124077	2025-11-07 10:55:01.927215	\N	\N	daniel chang	\N
1076	dbae69e5-35d9-4dce-9fbe-21ae577b74bd	1	3	\N	Jonathan Loo Ko	\N	\N	t	2025-11-07 10:55:17.255766	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": "--"}	2025-11-07 08:47:09.114327	2025-11-07 10:55:17.256603	\N	\N	jonathan loo ko	\N
1086	c55e8f22-bfd8-48bc-84bc-537ee0630988	1	3	\N	Ps Steven Choon	\N	\N	t	2025-11-07 10:56:56.876153	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.19381	2025-11-07 10:56:56.876781	\N	\N	ps steven choon	\N
1098	5c4e3a28-dad5-4a88-ac69-24dd0849bb55	1	3	\N	Wang Yi Shi	\N	\N	t	2025-11-07 11:04:51.018168	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.297725	2025-11-07 11:04:51.018914	\N	\N	wang yi shi	\N
1090	761e54d8-3e5c-40fa-9775-44c7a31ad8ff	1	3	\N	Elden Chang	\N	\N	t	2025-11-07 10:57:50.876836	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.226469	2025-11-07 10:57:50.87745	\N	\N	elden chang	\N
1091	c574123f-3bfc-4872-9185-cd41cc89eb10	1	3	\N	Francis Tham Chee Ming	\N	\N	t	2025-11-07 11:01:57.962074	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Pastor Fellowship Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.232853	2025-11-07 11:01:57.962782	\N	\N	francis tham chee ming	\N
1093	3eae99d5-2fb2-4dce-b8c2-803c097a784a	1	3	\N	Kapitan Dr. Tan Kai Li	\N	\N	t	2025-11-07 11:04:12.848868	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "deputy president", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.251204	2025-11-07 11:04:12.849603	\N	\N	kapitan dr. tan kai li	\N
1094	8a717d55-8bcf-415c-8ef5-72437a234691	1	3	\N	Ngan Yoke Loo	\N	\N	t	2025-11-07 11:04:19.167605	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.262186	2025-11-07 11:04:19.168223	\N	\N	ngan yoke loo	\N
1096	bba7bb94-6676-4749-9523-5682832ce138	1	3	\N	Foo Sze Leong	\N	\N	t	2025-11-07 11:04:40.980878	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.277937	2025-11-07 11:04:40.981582	\N	\N	foo sze leong	\N
1095	79318113-99a6-41c9-9489-31374a335c50	1	3	\N	Ong Hwa Tung	\N	\N	t	2025-11-07 11:49:07.35894	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.272174	2025-11-07 11:49:07.359725	\N	\N	ong hwa tung	\N
1097	ad4a0159-a085-4aee-813c-04e304ab3bd7	1	3	\N	Pang Yok Ming	\N	\N	t	2025-11-07 11:49:31.140554	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.288015	2025-11-07 11:49:31.141279	\N	\N	pang yok ming	\N
1099	50471715-3240-48a3-b392-783f69212fa8	1	3	\N	Steward Pang	\N	\N	t	2025-11-07 11:50:38.577763	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.306262	2025-11-07 11:50:38.578505	\N	\N	steward pang	\N
1110	fbd52df5-85c7-4e9b-8f35-9bb5608db70e	1	3	\N	Tan Chong Hung	\N	\N	t	2025-11-08 02:38:20.984588	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.421726	2025-11-08 02:38:20.985233	\N	\N	tan chong hung	\N
2026	a3ebd304-cf2a-487c-a339-a02ebb8f897b	1	1	\N	Edmund Tham	\N	\N	t	2025-11-11 07:00:13.208066	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "XPOSURE PRODUCTION", "position": "DIRECTOR"}	2025-11-11 07:00:00.532147	2025-11-11 07:00:13.208878	\N	\N	edmund tham	\N
2039	0f8bbe1b-6d07-4c47-b88d-bc5e77d394f4	1	1	\N	Dr Khai	\N	\N	t	2025-11-11 07:31:47.1572	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "RADIANT SKIN", "position": "DIRECTOR"}	2025-11-11 07:31:35.936338	2025-11-11 07:31:47.158004	\N	\N	dr khai	\N
1102	0b7783e4-aa19-43c9-8e98-8f83f716ee1e	1	3	\N	Kelvin Hing Yick Fong	\N	\N	t	2025-11-07 11:06:24.470758	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.33322	2025-11-07 11:06:24.471475	\N	\N	kelvin hing yick fong	\N
1109	4d7dc752-fac2-4d9f-9210-333b1d0da6f2	1	3	\N	Pong Shui Lin	\N	\N	t	2025-11-07 11:12:18.321035	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.410867	2025-11-07 11:12:18.321649	\N	\N	pong shui lin	\N
1108	a24710f2-8d8a-4122-9d1e-6e929f158132	1	3	\N	Chin Ka Foh	\N	\N	t	2025-11-07 11:13:52.88678	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.401621	2025-11-07 11:13:52.887436	\N	\N	chin ka foh	\N
1117	280edb9e-97b2-43fe-beec-27557739258a	1	3	\N	Loong Kok Seng	\N	\N	t	2025-11-07 11:16:57.475547	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.476968	2025-11-07 11:16:57.476119	\N	\N	loong kok seng	\N
1107	aa09d1ca-3551-4d5b-9c6f-f3813fd5f8e4	1	3	\N	Pang Boon Eme	\N	\N	t	2025-11-07 11:16:01.031857	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.391928	2025-11-07 11:16:01.032626	\N	\N	pang boon eme	\N
1118	be650606-7851-4034-8231-b91c1481d2d9	1	3	\N	Henry Tan Shin Ren	\N	\N	t	2025-11-07 11:17:22.483447	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.486304	2025-11-07 11:17:22.484108	\N	\N	henry tan shin ren	\N
1111	4146f105-8137-4466-8c9d-daa8e7814087	1	3	\N	Richard Chong Vui Kwan	\N	\N	t	2025-11-07 11:17:25.110468	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.430618	2025-11-07 11:17:25.111015	\N	\N	richard chong vui kwan	\N
1112	4d47b383-6a1e-4211-ac92-f8f26cef2309	1	3	\N	Yee Yu Ket	\N	\N	t	2025-11-07 11:17:46.935862	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.439663	2025-11-07 11:17:46.936451	\N	\N	yee yu ket	\N
1119	c5ab7d56-8b2f-4cea-97a0-3a4a601e9d06	1	3	\N	Liew Wah Yi	\N	\N	t	2025-11-07 11:17:47.621172	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.494097	2025-11-07 11:17:47.621725	\N	\N	liew wah yi	\N
1113	4685da54-b7c4-4e88-b980-5c76d37d29ce	1	3	\N	Lester Wong Tze Vui	\N	\N	t	2025-11-07 11:18:08.775024	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.447862	2025-11-07 11:18:08.776158	\N	\N	lester wong tze vui	\N
1120	ed17ec7c-1c6c-456d-af33-a3538a20c087	1	3	\N	Chua Yuan Sen	\N	\N	t	2025-11-07 11:20:21.534626	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.49994	2025-11-07 11:20:21.535446	\N	\N	chua yuan sen	\N
1114	588d74e8-826f-49de-a39f-6438b34210cd	1	3	\N	Wong Huong Jenn @ Kevin	\N	\N	t	2025-11-07 11:20:25.471308	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.455043	2025-11-07 11:20:25.472078	\N	\N	wong huong jenn @ kevin	\N
1115	26e08733-2538-4860-9f14-cc394994af00	1	3	\N	Paul Tan Shin Yu	\N	\N	t	2025-11-07 11:20:42.626124	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.460932	2025-11-07 11:20:42.626824	\N	\N	paul tan shin yu	\N
1116	0dc4a16e-1404-48d6-aa49-e3fdfb5d8f94	1	3	\N	Jackson Voo	\N	\N	t	2025-11-07 11:20:57.590077	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.469062	2025-11-07 11:20:57.590711	\N	\N	jackson voo	\N
1122	914f8217-278a-4c67-b7b8-4fc66fc16516	1	3	\N	Alvin Lee Fook Lim	\N	\N	t	2025-11-07 11:21:06.622074	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.510474	2025-11-07 11:21:06.622933	\N	\N	alvin lee fook lim	\N
1123	f138c152-87c1-4bc9-a387-49539636853b	1	3	\N	Joanne Lim Fong Yee	\N	\N	t	2025-11-07 11:21:14.932781	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.51615	2025-11-07 11:21:14.93331	\N	\N	joanne lim fong yee	\N
1124	f5384e80-e566-4c55-bd39-fd06089346e5	1	3	\N	Shim Nyet Soon	\N	\N	t	2025-11-07 11:21:39.095303	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.521123	2025-11-07 11:21:39.095972	\N	\N	shim nyet soon	\N
1125	2c86e281-921d-4a4f-8107-d9148e1beec7	1	3	\N	Gil Chong Chien Chin	\N	\N	t	2025-11-07 11:21:48.741567	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.526834	2025-11-07 11:21:48.742073	\N	\N	gil chong chien chin	\N
1100	fa91f2f3-c68c-45ff-a095-b5986b59fc04	1	3	\N	Lai Jong Jinn	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.314937	2025-11-07 11:51:27.985204	\N	\N	lai jong jinn	\N
1103	2438661f-4432-4fb7-a190-acec63c29b06	1	3	\N	Alice Chan	\N	\N	t	2025-11-07 11:52:51.939699	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.355456	2025-11-07 11:52:51.940399	\N	\N	alice chan	\N
1104	9d07f7e7-793b-4ffc-aca0-14c02a1b6b8c	1	3	\N	Jeff Ngan	\N	\N	t	2025-11-07 11:55:00.086516	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.366217	2025-11-07 11:55:00.08722	\N	\N	jeff ngan	\N
1105	35143a02-1ecc-4c07-9c8e-2f0dd4ed1067	1	3	\N	Beatrice Foo	\N	\N	t	2025-11-07 11:55:10.810263	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.374956	2025-11-07 11:55:10.810951	\N	\N	beatrice foo	\N
1106	c75ae603-b027-4ddf-8d1f-b2d3af49e32d	1	3	\N	Gary Lim Ming Ong	\N	\N	t	2025-11-07 11:55:21.306423	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Hainan Association Kota Kinabalu", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.383278	2025-11-07 11:55:21.307005	\N	\N	gary lim ming ong	\N
1300	fddef665-aa16-4f37-ace7-66eb3a54a213	1	3	\N	Chong Chi Wai	\N	60139685537	t	2025-11-08 01:06:03.42828	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "SYARIKAT LUI KIM CHOCK SDN BHD", "position": "MIS ADMIN EXECUTIVE"}	2025-11-08 01:04:19.024212	2025-11-08 01:06:03.429043	\N	60139685537	chong chi wai	\N
1151	c787f4e1-1e9b-4603-99da-98c289252cf9	1	1	\N	Chua Wei Shen	Chuaweishen010@gmail.com	601172611961	t	2025-11-07 08:55:25.451861	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ninetysix aluminium and glass works", "position": "staff"}	2025-11-07 08:55:25.451861	2025-11-07 08:55:25.451861	chuaweishen010@gmail.com	601172611961	chua wei shen	\N
1152	202e469c-2711-4451-9602-dfa13298a3bd	1	1	\N	Ha Gien Kuan	dannyha@gmail.com	60167139657	t	2025-11-07 08:55:30.987024	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ninety six aluminium work enterprise", "position": "Boss"}	2025-11-07 08:55:30.987024	2025-11-07 08:55:30.987024	dannyha@gmail.com	60167139657	ha gien kuan	\N
1127	b918f250-abb3-4c43-89f5-e512cde57c0e	1	3	\N	Alvin Saw Eng Seng	\N	\N	t	2025-11-07 11:22:36.295934	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.53907	2025-11-07 11:22:36.296842	\N	\N	alvin saw eng seng	\N
1150	6f96d78c-a14c-4cea-83ed-0565ce5dda35	1	1	\N	Sufi	kggirl06@gmail.com	601114100567	t	2025-11-07 08:52:45.333195	26	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Megan 9", "position": "Sales advisor"}	2025-11-07 08:52:28.356594	2025-11-07 08:52:45.333794	kggirl06@gmail.com	601114100567	sufi	\N
1128	4371db72-2d0a-4452-bfcc-6af8194ce2b8	1	3	\N	Danny Hei Yeong Keong	\N	\N	t	2025-11-07 11:22:43.304399	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.544703	2025-11-07 11:22:43.305112	\N	\N	danny hei yeong keong	\N
1130	9eb70a1c-b7f5-49f6-aaf7-7e3b360400f2	1	3	\N	Lucy Wong Siong Ching	\N	\N	t	2025-11-07 11:23:20.687587	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.560985	2025-11-07 11:23:20.688493	\N	\N	lucy wong siong ching	\N
1131	81a9648d-5b47-4682-ba34-9249d8133160	1	3	\N	Eric Lau Kah Hon	\N	\N	t	2025-11-07 11:23:26.61002	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.566937	2025-11-07 11:23:26.610791	\N	\N	eric lau kah hon	\N
1132	ccc9a261-59f3-447f-8d6d-f73287e029b9	1	3	\N	Ham Cheng Siong	\N	\N	t	2025-11-07 11:23:32.607174	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.573489	2025-11-07 11:23:32.607881	\N	\N	ham cheng siong	\N
1133	0c00a692-1df8-4995-ae28-fcdc91a1e5e8	1	3	\N	Kiung Jeon Shii	\N	\N	t	2025-11-07 11:23:55.75078	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.578757	2025-11-07 11:23:55.751495	\N	\N	kiung jeon shii	\N
1134	6405f627-101f-46f3-a7cd-e94623a1c325	1	3	\N	Pang Miao Zi	\N	\N	t	2025-11-07 11:24:00.730798	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.585015	2025-11-07 11:24:00.731542	\N	\N	pang miao zi	\N
1135	540a0187-0fac-4ae0-8d74-73ef739e01cc	1	3	\N	Yong Min Yau	\N	\N	t	2025-11-07 11:24:04.899522	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.591121	2025-11-07 11:24:04.900146	\N	\N	yong min yau	\N
1136	8ab46f67-dd60-4b33-bc3c-f0ee89c8759c	1	3	\N	Kuo Pui Ling	\N	\N	t	2025-11-07 11:24:09.885929	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.597132	2025-11-07 11:24:09.886783	\N	\N	kuo pui ling	\N
1142	60dbcf3b-95b8-47ed-ba68-c0f81f86419e	1	3	\N	Crystal Lee Xin Ying	\N	\N	t	2025-11-07 11:24:32.720534	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lion club of KK Capital", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.647516	2025-11-07 11:24:32.721224	\N	\N	crystal lee xin ying	\N
1137	662c0e4e-3a13-4ddf-b373-b89c00d4704d	1	3	\N	Chung Then Yong	\N	\N	t	2025-11-07 11:24:39.012312	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.606505	2025-11-07 11:24:39.01301	\N	\N	chung then yong	\N
1138	0a6a76ef-afa9-4db5-b24c-67bc931f30ea	1	3	\N	Lee Chee Soon	\N	\N	t	2025-11-07 11:24:42.955752	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.614753	2025-11-07 11:24:42.956486	\N	\N	lee chee soon	\N
1139	b1065535-e561-47cd-b803-31b726c94404	1	3	\N	Chong Oi Chin	\N	\N	t	2025-11-07 11:24:47.572343	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.620674	2025-11-07 11:24:47.572991	\N	\N	chong oi chin	\N
1140	b84cd952-5fd3-4fc1-b521-cbf46ad8f8aa	1	3	\N	Peggy Liow Vui Kun	\N	\N	t	2025-11-07 11:24:52.23376	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.630805	2025-11-07 11:24:52.234468	\N	\N	peggy liow vui kun	\N
1143	aafa1ae0-b87d-4c2e-8e7f-7e142a2ccb2b	1	3	\N	Bryan Chee Tze Tsong	\N	\N	t	2025-11-07 11:24:53.281258	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lion club of KK Capital", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.653974	2025-11-07 11:24:53.282236	\N	\N	bryan chee tze tsong	\N
1141	deb131cb-d7d0-48ed-ba77-81b0af63028d	1	3	\N	Desmond Chong Jia Nam	\N	\N	t	2025-11-07 11:25:16.098936	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Liberal Democratic Party", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.639156	2025-11-07 11:25:16.099681	\N	\N	desmond chong jia nam	\N
1145	6c6b436d-e636-4d16-8bf3-d289f453cd29	1	3	\N	Kent Wong Chee Teck	\N	\N	t	2025-11-07 11:26:09.141642	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lion club of KK Capital", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.669149	2025-11-07 11:26:09.142401	\N	\N	kent wong chee teck	\N
1144	a03f2b10-923a-41dc-a7bb-6c78c68422d8	1	3	\N	Roger Loo Wei Loong	\N	\N	t	2025-11-07 11:26:24.556673	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lion club of KK Capital", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.660549	2025-11-07 11:26:24.557305	\N	\N	roger loo wei loong	\N
1148	dd9e17d0-a9f6-4786-8ae9-085b5aac80a7	1	3	\N	Lanice	\N	\N	t	2025-11-07 11:27:16.173623	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SC Lighting Sdn Bhd", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.692659	2025-11-07 11:27:16.174238	\N	\N	lanice	\N
1147	f9754900-592a-43db-9315-b51f56db8725	1	3	\N	Gan Bee Kee	\N	\N	t	2025-11-07 13:00:58.620816	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ugo child care", "position": "Principal", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.68296	2025-11-07 13:00:58.621696	\N	\N	gan bee kee	\N
195	38dbe820-b8e9-43a9-b0ba-72f86902c267	1	3	\N	Fiona Pang Ling Xuan	\N	016-8391226	t	2025-11-07 08:59:02.181838	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "Student", "coupon_referral": "", "business_industry": "Education", "print_exhibitor_tag": ""}	2025-11-03 08:18:50.746202	2025-11-07 08:59:02.182513	\N	0168391226	fiona pang ling xuan	\N
1072	61a9c206-0f53-4f80-a886-58dd6fb0d28e	1	3	\N	Carmen Lim	\N	\N	t	2025-11-07 08:59:29.221404	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "BCCM Likas", "position": ""}	2025-11-07 08:47:09.084791	2025-11-07 08:59:29.221989	\N	\N	carmen lim	\N
1154	6dbeaf6c-94d7-49aa-93cc-68871f73f772	1	1	\N	Natasha Law	Nicoleleong2@hotmail.com	60168100909	t	2025-11-07 09:12:37.77556	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Niclovehandmade", "position": "Assistance"}	2025-11-07 09:12:17.83245	2025-11-07 09:12:37.776161	nicoleleong2@hotmail.com	60168100909	natasha law	\N
1153	6236b8c5-1020-4fc1-b6a5-be042ec03890	1	1	\N	Sabri Bin Abdullah	sabriabdullah490@gmail.con	60166186204	t	2025-11-07 08:59:47.600454	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabri", "position": "Bos"}	2025-11-07 08:59:47.600454	2025-11-07 08:59:47.600454	sabriabdullah490@gmail.con	60166186204	sabri bin abdullah	\N
1155	befa0ea9-ab77-464e-9d23-bcc717fa93a0	1	1	\N	Tiong Vic Tor	tngvictor1982@gmail.com	60128676371	t	2025-11-07 09:13:02.821118	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "A", "position": "A"}	2025-11-07 09:13:02.821118	2025-11-07 09:13:02.821118	tngvictor1982@gmail.com	60128676371	tiong vic tor	\N
1202	ca9b12c8-a4da-460a-b6b0-0c6eab999ba1	1	1	\N	Annah Pahaluddin	eaadina21@gmai.com	601131443424	t	2025-11-07 12:14:36.392096	23	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "Berjiria Juta Group", "position": "Manager"}	2025-11-07 12:08:55.931251	2025-11-07 12:14:36.39278	eaadina21@gmai.com	601131443424	annah pahaluddin	\N
1246	2712fc2a-298f-4ba5-bf20-ff90ed27efaa	1	1	\N	Janice Lee	janice.syntian@gmail.com	601110081177	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Kian kok middle School"}	2025-11-08 00:34:02.820466	2025-11-08 00:34:02.820466	janice.syntian@gmail.com	601110081177	janice lee	\N
1248	b7bed881-d514-448f-92a8-70995f0f53ca	1	1	\N	Jordon Wong	wxjjordon@gmail.com	601118515933	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Kian Kok Middle School "}	2025-11-08 00:34:52.202271	2025-11-08 00:34:52.202271	wxjjordon@gmail.com	601118515933	jordon wong	\N
1253	79bfc935-042f-4e19-8f34-86de4e0adaa0	1	1	\N	Felicia Ngoh Mee Ching	feliciangoh93@gmail.com	601137134902	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "None", "position": "None"}	2025-11-08 00:37:23.516622	2025-11-08 00:37:23.516622	feliciangoh93@gmail.com	601137134902	felicia ngoh mee ching	\N
1244	4c2dbf41-e047-488f-b1dc-a7326de47cef	1	1	\N	Chong Cha Chye	chong20071123@gmail.com	60168226721	t	2025-11-08 00:40:08.73148	\N	1	1	\N	\N	\N	{"role": "Student", "company": "KIAN KOK MIDDLE SCHOOL"}	2025-11-08 00:33:44.771113	2025-11-08 00:40:08.732026	chong20071123@gmail.com	60168226721	chong cha chye	\N
1249	2d261f22-d41e-4591-ab23-39f74dead0f4	1	1	\N	Du Xin Nuo	Jessiedu070220@Gmail.com	60178104321	t	2025-11-08 00:38:24.179693	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "kian kok"}	2025-11-08 00:35:12.566769	2025-11-08 00:38:24.180279	jessiedu070220@gmail.com	60178104321	du xin nuo	\N
1255	9aeeafd4-3a31-47db-9119-64c6c0a9a869	1	3	\N	Eric Len Joon Yih	\N	60109683830	t	2025-11-08 00:38:33.633422	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Nil", "position": "Um"}	2025-11-08 00:37:39.475861	2025-11-08 00:38:33.633981	\N	60109683830	eric len joon yih	\N
1247	09e89b26-8917-49e3-8927-27522a08cdef	1	1	\N	Fiona Pang Ling Xuan	fionapang2612@gmail.com	60168391226	t	2025-11-08 00:40:27.432327	\N	1	1	\N	\N	\N	{"role": "Student", "company": "Kian Kok Middle School "}	2025-11-08 00:34:06.786793	2025-11-08 00:40:27.433026	fionapang2612@gmail.com	60168391226	fiona pang ling xuan	\N
1235	c7883509-0b08-4e5f-bfdc-2153190da903	1	1	\N	Rachel Janice Tai Xing Mei	racheltai0122@gmail.com	60162102383	t	2025-11-08 00:40:30.920217	\N	1	1	\N	\N	\N	{"role": "Student", "company": "Kian kok Middle School"}	2025-11-08 00:31:07.236724	2025-11-08 00:40:30.920836	racheltai0122@gmail.com	60162102383	rachel janice tai xing mei	\N
1259	49a83663-f14d-4862-9753-b8bbb522dfe6	1	1	\N	Lydia Beh	Bsl@s1asiapac.com	60168336688	t	2025-11-08 00:42:03.16452	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "S1asiapac", "position": "Director"}	2025-11-08 00:41:43.747003	2025-11-08 00:42:03.165263	bsl@s1asiapac.com	60168336688	lydia beh	\N
1258	da5680af-53f3-491b-b32c-9c607f05617e	1	3	\N	Lee Siew Ken	\N	60168389888	t	2025-11-08 00:42:54.331843	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "che sui khor", "position": "admin "}	2025-11-08 00:40:13.156539	2025-11-08 00:42:54.332408	\N	60168389888	lee siew ken	\N
1260	8f72042a-0f7a-4c71-8381-aa009563a8d5	1	1	\N	Ian Isaac Majawat	ianisaac112@gmail.com	60122620463	t	2025-11-08 00:43:06.831936	\N	1	1	\N	\N	\N	{"role": "Student", "company": "Kota Kinabalu High School"}	2025-11-08 00:42:32.278396	2025-11-08 00:43:06.832682	ianisaac112@gmail.com	60122620463	ian isaac majawat	\N
1257	980fac49-c705-481e-b76e-18a91cff4613	1	3	\N	Queenie Chew Jing Weng	\N	60146503306	t	2025-11-08 00:43:25.354132	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "che sui khor", "position": "admin"}	2025-11-08 00:40:11.58279	2025-11-08 00:43:25.354727	\N	60146503306	queenie chew jing weng	\N
1262	9491db34-50a7-416d-ae1e-76a5a18a6053	1	3	\N	Dr Brian Wong	\N	60168333747	t	2025-11-08 00:45:32.633966	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Wanlin", "position": "CEO"}	2025-11-08 00:44:47.597797	2025-11-08 00:45:32.634552	\N	60168333747	dr brian wong	\N
1261	65464d71-380c-4544-8f1a-0f72e10f9f09	1	3	\N	Xu Guo Jia	\N	60138663178	t	2025-11-08 00:45:39.16224	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Tshung Tsin Secondary School", "position": "Student"}	2025-11-08 00:42:42.270232	2025-11-08 00:45:39.162766	\N	60138663178	xu guo jia	\N
1265	ab04746e-ed56-4d3a-874f-b56ace6ff29e	1	1	\N	Adrey Lee Chung Lii	adreylcl1007@gmail.com	60109357887	t	2025-11-08 00:47:30.385274	29	1	1	\N	\N	\N	{"role": "Student", "company": "MSU"}	2025-11-08 00:46:34.625076	2025-11-08 00:47:30.38602	adreylcl1007@gmail.com	60109357887	adrey lee chung lii	\N
1269	736ff2c6-6936-47ec-ac64-d07d3c63dc7f	1	3	\N	Liau Chen Hong	\N	601136308766	t	2025-11-08 00:47:47.513295	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "HIN GEN SDN BHD", "position": "CEO"}	2025-11-08 00:47:15.984061	2025-11-08 00:47:47.51392	\N	601136308766	liau chen hong	\N
1270	14ea8c99-aba9-4cf8-a83d-99bcdc9d0f6d	1	3	\N	Wong Siew Don	\N	60138656878	t	2025-11-08 00:50:39.774807	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Na ", "position": "Na"}	2025-11-08 00:47:55.802281	2025-11-08 00:50:39.775504	\N	60138656878	wong siew don	\N
1272	724ccd25-f47a-49cf-b4b6-c216251756bb	1	3	\N	Jan Chow	\N	60168485378	t	2025-11-08 00:54:12.254783	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Private", "position": "-"}	2025-11-08 00:48:25.367214	2025-11-08 00:54:12.255416	\N	60168485378	jan chow	\N
1316	0802c127-670b-4ba9-9986-1df87dde44c2	1	3	\N	Sia Siew Ling	\N	60168319680	t	2025-11-08 01:10:41.556276	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG PROPERTIES SDN BHD", "position": "ACCOUNTS EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 01:10:26.171609	2025-11-12 01:26:41.134062	\N	60168319680	sia siew ling	\N
1281	abeabe17-07da-4e77-9c35-717598df25e2	1	3	\N	Tang Vui Shing	\N	60168408010	t	2025-11-08 00:54:42.639165	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "TADIKA ST FRANCIS CONVENT", "position": "ASSISTANT PRINCIPAL"}	2025-11-08 00:52:59.314083	2025-11-08 00:54:42.639847	\N	60168408010	tang vui shing	\N
1275	30a45ac8-7eba-45d6-868c-f79c5b427827	1	3	\N	James Kang	\N	60128204855	t	2025-11-08 00:51:29.134096	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "ZUMA", "position": "CTO"}	2025-11-08 00:51:11.231149	2025-11-08 00:51:29.134795	\N	60128204855	james kang	\N
1274	41066450-e4a2-46ef-9f09-2c14ccd73c40	1	3	\N	Elizabeth Ching Jia Xuan	\N	601131766889	t	2025-11-08 00:55:58.632453	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Tshung Tsin Secondary School ", "position": "Student"}	2025-11-08 00:51:01.340619	2025-11-08 00:55:58.633121	\N	601131766889	elizabeth ching jia xuan	\N
1282	c6a6706e-385a-4e42-96ec-973328127390	1	3	\N	Michael Kang Jing Xiong	\N	60163010800	t	2025-11-08 00:53:43.998563	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "SEKOLAH TINGGI KOTA KINABALU", "position": "STUDENT"}	2025-11-08 00:53:14.283167	2025-11-08 00:53:43.999269	\N	60163010800	michael kang jing xiong	\N
1276	ed00fbb7-0e12-46a8-b461-233c4fbd58cd	1	3	\N	Jamie Wong	\N	60168298788	t	2025-11-08 00:56:04.799596	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "崇正中学", "position": "Teacher"}	2025-11-08 00:51:22.538387	2025-11-08 00:56:04.800544	\N	60168298788	jamie wong	\N
1279	3034e08e-91c6-46f3-916e-2db8172fa683	1	3	\N	Jeanne Chin	\N	60138160426	t	2025-11-08 00:56:41.765121	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "JC reworks", "position": "Founder"}	2025-11-08 00:52:13.425236	2025-11-08 00:56:41.765743	\N	60138160426	jeanne chin	\N
1280	28c2321a-12d5-43f7-996f-537033f92e0c	1	3	\N	Liew San San	\N	60168091998	t	2025-11-08 00:57:26.704533	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Grace chapel Penampang", "position": "Pastor"}	2025-11-08 00:52:39.018532	2025-11-08 00:57:26.705035	\N	60168091998	liew san san	\N
1307	353916b6-5cde-4057-9475-edfb467ac70e	1	1	\N	Wong Gha Ho	jiahe7373@hotmail.com	60168279417	t	2025-11-08 01:06:27.01088	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "MCCC (SABAH)", "position": "Member"}	2025-11-08 01:06:11.431276	2025-11-08 01:06:27.011483	jiahe7373@hotmail.com	60168279417	wong gha ho	\N
1306	8ce3db8b-ab8e-45c5-85a5-2086a874baa4	1	3	\N	Melisse Lim Zhi Xin	\N	60125130819	t	2025-11-08 01:06:31.771026	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah Tshung Tsin Secondary School", "position": "Student"}	2025-11-08 01:06:06.442496	2025-11-08 01:06:31.771712	\N	60125130819	melisse lim zhi xin	\N
1309	f8de071e-3d8e-4fae-a265-f49218e76ca5	1	3	\N	Lim Boon Kiat	\N	60125708644	t	2025-11-08 01:06:37.175498	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sabah tshung tsin school ", "position": "Teacher "}	2025-11-08 01:06:21.111716	2025-11-08 01:06:37.176123	\N	60125708644	lim boon kiat	\N
1295	25bbc881-8ee0-4a5b-9a2a-1737f2fe1498	1	3	\N	Tee Kwok Chiang	\N	60168318224	t	2025-11-08 01:06:57.019199	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Church", "position": "Paster"}	2025-11-08 01:02:06.175699	2025-11-08 01:06:57.019811	\N	60168318224	tee kwok chiang	\N
1286	043071f6-239b-42ef-91aa-ebd8302c4c40	1	3	\N	Isaiah Liew Jin Khen	\N	60128388757	t	2025-11-08 01:07:01.264794	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "ST borneo", "position": "Operation manager"}	2025-11-08 00:54:55.776012	2025-11-08 01:07:01.265501	\N	60128388757	isaiah liew jin khen	\N
1311	2b2b2adb-f70a-4355-94ab-e5064af58ae5	1	3	\N	Elsen Chang	\N	60183848246	t	2025-11-08 01:08:26.119158	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Boya Nanyang", "position": "Manager"}	2025-11-08 01:08:13.256705	2025-11-08 01:08:26.119851	\N	60183848246	elsen chang	\N
1310	ef511a0e-e1b6-4246-b4ac-fe6f1aa78df2	1	1	\N	Goh Pei Hwa	gohph@tarc.edu.my	60168276218	t	2025-11-08 01:08:32.637306	29	1	1	\N	\N	\N	{"role": "Lecturer", "company": "TAR UMT"}	2025-11-08 01:07:13.037994	2025-11-08 01:08:32.637967	gohph@tarc.edu.my	60168276218	goh pei hwa	\N
1314	c97e77b4-f7b3-472e-b294-77daa4a8087a	1	1	\N	Fanny Khoo	fanny6100@yahoo.com	60128310919	t	2025-11-08 01:09:19.541953	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "MCCC Sabah", "position": "Commit"}	2025-11-08 01:09:00.863004	2025-11-08 01:09:19.542663	fanny6100@yahoo.com	60128310919	fanny khoo	\N
1315	69976611-6824-4795-b338-a550e1fa0481	1	3	\N	Khor Siew Eng	\N	60163313050	t	2025-11-08 01:10:13.808983	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Keyloop", "position": "Consultant"}	2025-11-08 01:09:57.997924	2025-11-08 01:10:13.809523	\N	60163313050	khor siew eng	\N
1317	709b670a-3d75-414d-9d95-b7bc7a11276a	1	3	\N	Chong Tong Seng	\N	60168405578	t	2025-11-08 01:11:13.439471	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Social Farming Enterprise PLT ", "position": "Manager"}	2025-11-08 01:10:58.588633	2025-11-08 01:11:13.440096	\N	60168405578	chong tong seng	\N
1308	24fde95f-c71b-4163-a3e5-bce790b5c564	1	3	\N	Joan Lee	\N	60168337133	t	2025-11-08 01:11:44.47393	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "HURRICANE SPORTS SDN HD", "position": "Admin"}	2025-11-08 01:06:20.353174	2025-11-08 01:11:44.474601	\N	60168337133	joan lee	\N
1320	8451b621-9699-400f-8874-a9284e626478	1	1	\N	Cyrus Yap Heng Jun	0221052@sttss.edu.my	60168415899	t	2025-11-08 01:13:20.017412	23	1	1	\N	\N	\N	{"role": "Student", "company": "Sabah Tshung Tsin Secondary School"}	2025-11-08 01:11:49.874712	2025-11-08 01:13:20.017974	0221052@sttss.edu.my	60168415899	cyrus yap heng jun	\N
1322	fb8fc974-be0d-457e-998f-d9ccf289117b	1	1	\N	Cho Yee Shuen	0211107@sttss.edu.my	60102487278	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sabah Tshung Tsin Secondary School"}	2025-11-08 01:12:16.438551	2025-11-08 01:12:16.438551	0211107@sttss.edu.my	60102487278	cho yee shuen	\N
1305	fc1b70bc-979c-4edd-8d15-03082d595384	1	3	\N	Phoebe Yong	\N	60168390068	t	2025-11-08 01:12:21.499973	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Vineyard Baptist Church ", "position": "Committee "}	2025-11-08 01:05:57.652665	2025-11-08 01:12:21.500578	\N	60168390068	phoebe yong	\N
1321	4543d06a-d670-48aa-b893-09f07a0eb2fc	1	1	\N	Anne Sia	siaanne763@gmail.com	60198279318	t	2025-11-11 05:56:11.327573	\N	1	1	\N	\N	\N	{"role": "Student", "company": "Sabah Tshung Tsin Secondary School"}	2025-11-08 01:12:14.15632	2025-11-11 05:56:11.328661	siaanne763@gmail.com	60198279318	anne sia	\N
1273	a4de71b2-4d9d-4f53-8b07-f99abae352c4	1	1	\N	Duncan Wong	duncanwhzheng@gmail.com	60128256006	t	2025-11-08 00:49:38.616576	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sri Luagan Hardware & Tools", "position": "Managing Director"}	2025-11-08 00:49:38.616576	2025-11-08 00:49:38.616576	duncanwhzheng@gmail.com	60128256006	duncan wong	\N
1318	5c5e4d06-5836-4e16-8ce0-2ebdd708c307	1	1	\N	Hwong Chee Ying	hwong0929@gmail.com	60168759141	t	2025-11-08 01:12:22.766435	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian kok middle school", "position": "Teacher"}	2025-11-08 01:11:26.050698	2025-11-08 01:12:22.766992	hwong0929@gmail.com	60168759141	hwong chee ying	\N
1323	1cd71b68-1ea5-41f2-93c7-78ac165c12fc	1	3	\N	Yong Han	\N	60137717393	t	2025-11-08 01:17:01.975223	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Yhms", "position": "Sole proprietor"}	2025-11-08 01:12:33.365258	2025-11-08 01:17:01.976344	\N	60137717393	yong han	\N
1319	5ce109c4-3232-43cb-848e-6bf3dc8b928d	1	1	\N	Elaine Cheong	elainecheong5@gmail.com	60168182117	t	2025-11-08 01:13:21.44981	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kian Kok Middle School", "position": "Teacher"}	2025-11-08 01:11:28.61523	2025-11-08 01:13:21.450363	elainecheong5@gmail.com	60168182117	elaine cheong	\N
1324	4aee44d3-e57c-411a-8a61-26bed206a76c	1	3	\N	Owen Seow	\N	61412030844	t	2025-11-08 01:13:34.510589	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "JH Bersatu Sdn Bhd", "position": "Director"}	2025-11-08 01:13:06.581038	2025-11-08 01:13:34.511106	\N	61412030844	owen seow	\N
1327	74d7c52b-fcda-47bd-9b25-ddace1da0b51	1	3	\N	Nl Wong	\N	60162940902	t	2025-11-08 01:16:25.050152	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Wonly sdn bhd", "position": "Director"}	2025-11-08 01:16:11.25318	2025-11-08 01:16:25.051026	\N	60162940902	nl wong	\N
1325	9ff65095-1d81-48a6-b16a-a88fd56a3128	1	3	\N	Celyne Foo	\N	60168391151	t	2025-11-08 01:16:40.513476	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "YHMS", "position": "Executive manager"}	2025-11-08 01:13:15.242911	2025-11-08 01:16:40.514138	\N	60168391151	celyne foo	\N
1328	d6927995-32a0-42bf-9153-bbcb616a9c27	1	3	\N	Lo Shiau Wei	\N	60189600927	t	2025-11-08 01:16:50.898591	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "TSEN ENTERPRISE ", "position": "--"}	2025-11-08 01:16:35.928248	2025-11-08 01:16:50.899547	\N	60189600927	lo shiau wei	\N
1329	686a84f7-1935-40af-bab5-fc9728b5516d	1	3	\N	Sheena Tan	\N	60109552335	t	2025-11-08 01:18:52.014153	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "YMM Sabah", "position": "Vice Chairman"}	2025-11-08 01:18:37.092043	2025-11-08 01:18:52.015107	\N	60109552335	sheena tan	\N
1330	717b8772-a9e5-42bf-9531-65ae8d11131a	1	3	\N	Fish Liew	\N	60168200218	t	2025-11-08 01:19:23.5529	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ymm", "position": "Member"}	2025-11-08 01:19:09.397311	2025-11-08 01:19:23.55349	\N	60168200218	fish liew	\N
1333	801eb628-15d5-4ffc-800f-4f613b7dbb0c	1	3	\N	Yong Min Yau	\N	60168441057	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Drom Yong Agency", "position": "Manager"}	2025-11-08 01:20:46.748277	2025-11-08 01:20:46.748277	\N	60168441057	yong min yau	\N
1332	584b4c2e-5dbe-4c63-a027-dd6ff65e0811	1	3	\N	Tsenjingfeng	\N	601155136448	t	2025-11-08 01:20:55.05959	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "CFY.COM", "position": "Maketing"}	2025-11-08 01:20:32.651645	2025-11-08 01:20:55.060289	\N	601155136448	tsenjingfeng	\N
1326	08ba4f9c-3bbf-4d22-acf2-8136f99650ea	1	3	\N	Anthony Chung Ching Fatt	\N	6596830373	t	2025-11-08 01:21:05.212425	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sense Massage Sdn Bhd", "position": "Managing director"}	2025-11-08 01:16:03.675679	2025-11-08 01:21:05.213017	\N	6596830373	anthony chung ching fatt	\N
1331	09a32ac4-9d0c-4419-b53d-04ad7d0b1da1	1	3	\N	Chen Khan Chit	\N	60165843004	t	2025-11-08 01:21:09.930111	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "CFY.COM", "position": "Maketing"}	2025-11-08 01:20:27.457218	2025-11-08 01:21:09.930661	\N	60165843004	chen khan chit	\N
1334	26bfa57d-6075-40d4-919a-9c2853876f42	1	3	\N	Jonathan Liew Tzen Ching	\N	60146575826	t	2025-11-08 01:21:11.549105	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Sense Massage Sdn Bhd ", "position": "Director"}	2025-11-08 01:20:58.847939	2025-11-08 01:21:11.549782	\N	60146575826	jonathan liew tzen ching	\N
1336	8be427b9-8e48-4d83-9c69-50040ffc21c4	1	3	\N	Jerome Yong	\N	60138507607	t	2025-11-08 01:21:43.648924	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Percetakan CCS SDN BHD ", "position": "Director"}	2025-11-08 01:21:27.423666	2025-11-08 01:21:43.649452	\N	60138507607	jerome yong	\N
1335	a7788776-e463-4682-b6bb-9833d05763d3	1	3	\N	Wong Boon John	\N	60128671289	t	2025-11-08 01:56:01.608103	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "North Borneo Land Venture Sdn Bhd", "position": "Business Development Director"}	2025-11-08 01:21:10.18678	2025-11-08 01:56:01.608815	\N	60128671289	wong boon john	\N
1338	50bbf62b-4562-4156-87ac-c43ebf4ae887	1	3	\N	Jordan Chang	\N	60168311501	t	2025-11-08 01:25:10.047566	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "MCCC SABAH", "position": "Member"}	2025-11-08 01:24:56.981483	2025-11-08 01:25:10.048309	\N	60168311501	jordan chang	\N
1337	6735c744-fdb1-459c-88d3-a81800683edc	1	3	\N	Paul Tan Shin Yu	\N	60162439450	t	2025-11-08 01:25:13.105998	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "CBMC", "position": "Member "}	2025-11-08 01:24:43.766728	2025-11-08 01:25:13.106619	\N	60162439450	paul tan shin yu	\N
1339	af99cdd5-51f4-470a-a66d-84a6e28ff549	1	1	\N	Aiko Lim	yovinyovin@gmail.com	601117244931	t	2025-11-08 01:27:05.020408	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SME", "position": "Admin"}	2025-11-08 01:26:48.021371	2025-11-08 01:27:05.020979	yovinyovin@gmail.com	601117244931	aiko lim	\N
1341	b398edf4-9f09-4cd5-bf0e-e0f153258066	1	3	\N	Steven Kim	\N	60162250465	t	2025-11-08 01:29:24.346992	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Core Advisors Ltd", "position": "Wealth Advisor"}	2025-11-08 01:29:11.920906	2025-11-08 01:29:24.34753	\N	60162250465	steven kim	\N
1342	4120f3c5-d5af-45ce-b403-a8ce34192a26	1	3	\N	Lim Muh Ching	\N	60162251393	t	2025-11-08 01:30:17.339011	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lim Association", "position": "Member"}	2025-11-08 01:29:31.70019	2025-11-08 01:30:17.33969	\N	60162251393	lim muh ching	\N
1348	75662ff4-2e1a-4981-bc3a-6c72ec3e0ca9	1	3	\N	Hiew Kwan Yung	\N	60128699100	t	2025-11-08 02:03:58.448638	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Lim Association", "position": "member"}	2025-11-08 01:34:49.886451	2025-11-08 02:03:58.449234	\N	60128699100	hiew kwan yung	\N
1343	3655213d-19f9-44dc-b902-6c666b78ccb3	1	1	\N	Ng Lun Xin	nglunxin@outlook.com	60168459768	t	2025-11-08 01:32:26.355971	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Young Malaysian Movement ", "position": "Member "}	2025-11-08 01:31:07.369458	2025-11-08 01:32:26.356882	nglunxin@outlook.com	60168459768	ng lun xin	\N
1344	3b2a7ff8-c25c-4eeb-9c91-a0c9a2be6cf2	1	1	\N	Abel	Hcj5409@gmail.com	60165787797	t	2025-11-08 01:32:55.263906	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "YMM", "position": "State Exco"}	2025-11-08 01:32:32.252692	2025-11-08 01:32:55.26452	hcj5409@gmail.com	60165787797	abel	\N
1347	8e70688a-f418-49e7-8580-c79541b6fc64	1	3	\N	Alvis Hiew	\N	60128809100	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Jin Long Health Group (M) Sdn Bhd", "position": "Manager"}	2025-11-08 01:34:03.380779	2025-11-08 01:34:03.380779	\N	60128809100	alvis hiew	\N
1346	465abf8e-475b-4c65-a038-ff973ebcbaea	1	3	\N	Luk Mei Yee Shella	\N	601111734217	t	2025-11-08 01:36:20.657522	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "BeWonder Holding Sdn Bhd", "position": "Operation and Business Development Manager"}	2025-11-08 01:33:31.91291	2025-11-08 01:36:20.65818	\N	601111734217	luk mei yee shella	\N
1345	f11bb038-b6ee-486d-9454-f609bc88b8ae	1	3	\N	Angela Tan Pui Ling	\N	601136251284	t	2025-11-08 01:36:34.348906	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Bewonder holding SDN bhd ", "position": "Purchasing"}	2025-11-08 01:33:13.310702	2025-11-08 01:36:34.349428	\N	601136251284	angela tan pui ling	\N
1349	b9900241-4800-4263-ada0-9baf1b282da4	1	1	\N	Saila Nabila	sailanabila48@gmail.com	60109307076	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "BTC MAJU HOLDING SDN BHD (BTC FOODS)", "position": "SALES"}	2025-11-08 01:40:43.173774	2025-11-08 01:40:43.173774	sailanabila48@gmail.com	60109307076	saila nabila	\N
1350	0ba5c1dc-22ed-4315-b8ff-96bc58689152	1	3	\N	Cheow Yuan Sheng Jason	\N	60168234771	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Hong sheng enterprise ", "position": "Director "}	2025-11-08 01:48:03.197372	2025-11-08 01:48:03.197372	\N	60168234771	cheow yuan sheng jason	\N
1351	8dca617c-c048-421c-948b-62df2e911ec3	1	3	\N	Harry Vun Jie Xiong	\N	60168066670	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "GSG Hub Advisory Snd Bhd", "position": "Director "}	2025-11-08 01:54:45.053244	2025-11-08 01:54:45.053244	\N	60168066670	harry vun jie xiong	\N
1353	04dc303b-7657-4f2a-9022-60beb43327a7	1	3	\N	Rex Lee Kang Yan	\N	60163511431	t	2025-11-08 02:01:33.433443	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Young Malaysian Movement", "position": "Branch Chairman"}	2025-11-08 02:01:07.15639	2025-11-08 02:01:33.434116	\N	60163511431	rex lee kang yan	\N
51	66d9724e-b1ee-48b5-87c2-dba2221e1b68	1	9	\N	Carmen Cheah	\N	016-949 0209	t	2025-11-08 02:06:32.651375	\N	1	1	\N	\N	\N	{"role": "VVIP", "company": "Exabytes Network Sdn. Bhd.", "position": "MYSG Event Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:23:54.574311	2025-11-08 02:06:32.652072	\N	0169490209	carmen cheah	\N
1354	9f0ceb0e-700c-4a96-a84d-50e47a29f3b9	1	3	\N	Ooi Poh Yan	\N	60169490209	t	2025-11-08 02:09:20.553086	29	1	1	\N	\N	\N	{"role": "VVIP", "company": "Exabytes Network Sdn Bhd", "position": "VP of Sales"}	2025-11-08 02:08:24.003184	2025-11-08 02:09:20.553763	\N	60169490209	ooi poh yan	\N
1355	38d00a04-00bf-4fa0-97ef-94d32da77448	1	1	\N	Yong Nyuk Yun	Seaparkcondotel@yahoo.com	60128273787	t	2025-11-08 02:24:34.127628	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Chi Fatt Resources Sdn Bhd", "position": "Manager"}	2025-11-08 02:24:14.298988	2025-11-08 02:24:34.128229	seaparkcondotel@yahoo.com	60128273787	yong nyuk yun	\N
1356	a628d929-b68f-45c2-9fd3-95e74ae4f3e2	1	1	\N	Robert Pulz	Batoriginz84@gmail.com	60107707179	t	2025-11-08 02:27:14.606595	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "IPSOS SDN BHD", "position": "Survey Officer"}	2025-11-08 02:26:47.0486	2025-11-08 02:27:14.607157	batoriginz84@gmail.com	60107707179	robert pulz	\N
1359	c54ed6bf-e8a8-49d3-8e74-795e4a84ce5f	1	1	\N	Kee Lenny Binti Kee Abdul Hamid	Keelenny@gmail.com	60109321001	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "UNIFI", "position": "Sales"}	2025-11-08 02:29:06.986412	2025-11-08 02:29:06.986412	keelenny@gmail.com	60109321001	kee lenny binti kee abdul hamid	\N
1364	a44288aa-7c2a-4ccf-a64d-4334328ed596	1	1	\N	Fanny Lau Yien Chin	fannylau724@gmail.com	601135962625	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University Malaysia Sabah "}	2025-11-08 02:33:21.24396	2025-11-08 02:33:21.24396	fannylau724@gmail.com	601135962625	fanny lau yien chin	\N
1365	a9b50b83-fa7d-47b3-8cde-238cc2e80f34	1	1	\N	Cathy Chan Siew Wen	chansw1980@gmail.com	601131730659	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Ums"}	2025-11-08 02:33:33.620153	2025-11-08 02:33:33.620153	chansw1980@gmail.com	601131730659	cathy chan siew wen	\N
1366	d3644a4d-835e-4130-b360-63bbeecfd795	1	1	\N	Ling Ming Chee	mingcheeling@gmail.com	60178546995	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIVERSITI MALAYSIA SABAH (UMS)"}	2025-11-08 02:33:48.13772	2025-11-08 02:33:48.13772	mingcheeling@gmail.com	60178546995	ling ming chee	\N
1367	e46531f2-8c67-4e37-829d-3de6cfc968e2	1	1	\N	Chong Suk Chin	chongsukchin1210@gmail.com	60177366872	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-08 02:33:53.566291	2025-11-08 02:33:53.566291	chongsukchin1210@gmail.com	60177366872	chong suk chin	\N
1375	839f1cb7-357a-4d9c-b238-72e7c187f604	1	1	\N	May Yapp	mayyappruivun@gmail.com	601172550228	t	2025-11-08 02:44:40.140048	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG PROPERTIES SDN BHD", "position": "PERSONAL ASSISTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 02:43:43.902382	2025-11-12 01:26:52.285894	mayyappruivun@gmail.com	601172550228	may yapp	\N
1368	8d319ecb-d7af-416c-9f80-4adb05c85de0	1	1	\N	Kenneth	kennethmatias95@gmail.com	60165885624	t	2025-11-08 02:34:14.125151	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "N.S Lim & Co", "position": "Managing Partner"}	2025-11-08 02:34:14.125151	2025-11-08 02:34:14.125151	kennethmatias95@gmail.com	60165885624	kenneth	\N
1393	9050f343-db31-41e2-9136-6b9f1a0cae57	1	3	\N	Mayren Chung Yeat Yun	\N	60134358067	t	2025-11-08 02:58:18.665458	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG PROPERTIES SDN BHD", "position": "SALES EXECUTIVE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 02:58:06.619901	2025-11-12 01:27:02.109965	\N	60134358067	mayren chung yeat yun	\N
1394	fd372932-255e-45c8-8f74-4b7972d3c55b	1	3	\N	Leau Hen Ri	\N	601115099818	t	2025-11-08 03:00:15.7702	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "SCHOOL", "position": "Student"}	2025-11-08 03:00:03.051049	2025-11-08 03:00:15.770819	\N	601115099818	leau hen ri	\N
1396	6f1b6746-8ab0-4440-9657-0c2fcbdc8f42	1	1	\N	Lim Keat Wei	limkeatwei_bn23@iluv.ums.edu.my	60183846220	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-08 03:00:43.171956	2025-11-08 03:00:43.171956	limkeatwei_bn23@iluv.ums.edu.my	60183846220	lim keat wei	\N
1397	032eb559-2398-4528-9e79-2101f9286422	1	1	\N	Wang Huang Lin	whuanglin123@gmail.com	601113171727	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-08 03:00:50.761834	2025-11-08 03:00:50.761834	whuanglin123@gmail.com	601113171727	wang huang lin	\N
1401	43d70e48-a2d3-4f1d-bfa2-121eb4a880c4	1	3	\N	Andy Liau	\N	60146724808	t	2025-11-08 03:05:25.112813	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "The Well Cafe Sdn Bhd", "position": "CEO"}	2025-11-08 03:05:00.890967	2025-11-08 03:05:25.113338	\N	60146724808	andy liau	\N
1404	68cce369-6ad3-42e5-b583-fadd15ffc410	1	1	\N	Shany	srishafiqa@yahoo.com	60178136852	t	2025-11-08 03:07:48.531587	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Jalin Creative", "position": "Internship"}	2025-11-08 03:07:19.477952	2025-11-08 03:07:48.53227	srishafiqa@yahoo.com	60178136852	shany	\N
1405	c6e4bdb5-39ca-4310-8b12-6fdba19f3179	1	3	\N	Jenny Yu	\N	60168605631	t	2025-11-08 03:07:55.872894	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kong Lee Enterprise ", "position": "Admin Clerk"}	2025-11-08 03:07:34.15076	2025-11-08 03:07:55.873506	\N	60168605631	jenny yu	\N
1406	72e7d13d-42aa-40f3-916a-01b3eca9c825	1	1	\N	Khor Kah Shiong	kskhor21@gmail.com	60165365177	t	2025-11-08 03:08:33.707989	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Hardkhor Fitness Perkongsian Liabiliti Terhad ", "position": "Director "}	2025-11-08 03:08:05.368206	2025-11-08 03:08:33.70858	kskhor21@gmail.com	60165365177	khor kah shiong	\N
1407	2a8924d9-8d30-4d2f-b8d8-07bf4d5077ee	1	3	\N	Wilynie	\N	60138656863	t	2025-11-08 03:08:34.020912	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ums", "position": "Student"}	2025-11-08 03:08:13.785069	2025-11-08 03:08:34.021545	\N	60138656863	wilynie	\N
1408	23b80b3a-ee01-4d5b-97ce-c8c76130a34c	1	3	\N	Felicia	\N	60195815863	t	2025-11-08 03:09:03.951576	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Tumbu hardware enterprise ", "position": "Manger "}	2025-11-08 03:08:36.519026	2025-11-08 03:09:03.952995	\N	60195815863	felicia	\N
1409	89f02287-4d7f-4fdf-8294-b150668840af	1	3	\N	Bryan Chong Kah Hou	\N	60168605631	t	2025-11-08 03:09:12.578199	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Kong Lee Enterprise ", "position": "Student"}	2025-11-08 03:08:54.09801	2025-11-08 03:09:12.579036	\N	60168605631	bryan chong kah hou	\N
1411	65796f25-09d4-4001-b557-b4dd1671c445	1	1	\N	Kon Yuk Thiam	ytkon@ymail.com	60198803698	t	2025-11-08 03:12:10.217386	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Zuma engineering sdn bhd", "position": "Director"}	2025-11-08 03:11:30.894185	2025-11-08 03:12:10.217978	ytkon@ymail.com	60198803698	kon yuk thiam	\N
1395	68127591-11bd-4308-8b16-d00e885dae41	1	1	\N	Renee	reneechinny@gmail.com	60198806363	t	2025-11-08 03:00:23.664569	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 03:00:23.664569	2025-11-08 03:00:23.664569	reneechinny@gmail.com	60198806363	renee	\N
1425	74d52dbf-a369-437b-9531-48877ac7be9f	1	1	\N	Tiara Sibil	tiarasibil@yahoo.com	60168141291	t	2025-11-08 03:19:39.514191	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "PERSATUAN SAMA SABAH", "position": "Ahli Majlis Tertinggi PSS"}	2025-11-08 03:19:06.137157	2025-11-08 03:19:39.514817	tiarasibil@yahoo.com	60168141291	tiara sibil	\N
1429	9c11ef9c-48b1-444b-9978-e4d08894164b	1	1	\N	Abdul Syobir Bin Abdul Malik	abdulsyobir2006@gmail.com	60194853497	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Institut Kemahiran MARA Kota Kinabalu"}	2025-11-08 03:20:03.224016	2025-11-08 03:20:03.224016	abdulsyobir2006@gmail.com	60194853497	abdul syobir bin abdul malik	\N
1426	f827aaab-8d73-44a6-84cb-020e0dc3a412	1	1	\N	Oneh @ Latifah Osman	onehosman63@gmail.com	60147732863	t	2025-11-08 03:20:24.85702	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "PERTUBUHAN KIMARAGANG MALAYSIA ", "position": "MAJLIS TERTINGGI "}	2025-11-08 03:19:13.805435	2025-11-08 03:20:24.857725	onehosman63@gmail.com	60147732863	oneh @ latifah osman	\N
1434	dc68fd4a-9bdb-4e73-b0d8-c8981a0ff309	1	3	\N	Johnny Ghee	\N	60182936349	t	2025-11-08 03:25:29.786536	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "OtaiReformis1998Ventures", "position": "Director"}	2025-11-08 03:25:06.448049	2025-11-08 03:25:29.787133	\N	60182936349	johnny ghee	\N
1436	046796ed-9f9c-4bcd-8c27-2c14670cebc7	1	1	\N	Amat Rapie	amatrapie65@gmail.com	60146505001	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "SK mesapol"}	2025-11-08 03:31:56.629341	2025-11-08 03:31:56.629341	amatrapie65@gmail.com	60146505001	amat rapie	\N
1437	d729d461-46ed-460e-bb69-c5b02f5786a0	1	1	\N	Chris	kaifung97@gmail.com	60165201397	t	2025-11-08 03:35:55.735903	26	1	1	\N	\N	\N	{"role": "Delegate", "company": "Ymm Sabah", "position": "Deputy Chairman"}	2025-11-08 03:33:26.281983	2025-11-08 03:35:55.736579	kaifung97@gmail.com	60165201397	chris	\N
1440	d509bb29-a28b-4ead-9cfb-379302b88646	1	1	\N	Lucky	luckygoh@hotmail.com	60179359955	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "Universiti Malaysia Sabah"}	2025-11-08 03:36:58.981512	2025-11-08 03:36:58.981512	luckygoh@hotmail.com	60179359955	lucky	\N
1444	cce7a756-2f92-436c-974a-4dc93106cf9c	1	1	\N	Asnawi Raman	awieey.dollby@yahoo.com	60128447050	t	2025-11-08 03:41:23.35075	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Sama Sabah", "position": "Ahli PSS Busana Sama"}	2025-11-08 03:41:02.427967	2025-11-08 03:41:23.351309	awieey.dollby@yahoo.com	60128447050	asnawi raman	\N
1445	7eb69bed-8927-4038-bf9d-bfc100af803b	1	1	\N	Natashaj	Shahnatsha63@gmail.com	601127197717	t	2025-11-08 03:42:19.807574	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Persatuan Sama Sabah", "position": "Ahli PSS BUSANA SAMA"}	2025-11-08 03:41:57.714649	2025-11-08 03:42:19.808168	shahnatsha63@gmail.com	601127197717	natashaj	\N
1422	31c09c5e-37e3-4b41-a59f-f4a82eeb5a3d	1	1	\N	Razlan Bin Abdul Rahim	razlanabdrahim00@gmail.com	60189061171	t	2025-11-08 03:18:07.870215	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:18:07.870215	2025-11-08 03:18:07.870215	razlanabdrahim00@gmail.com	60189061171	razlan bin abdul rahim	\N
1439	9566fec7-0e14-42e0-983c-92745c6e2024	1	1	\N	Willonna Steffie	Suzanebunny87@gmail.com	601169376689	t	2025-11-08 03:48:30.213186	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "De 'Sr Resepi", "position": "Staff"}	2025-11-08 03:33:47.576236	2025-11-08 03:48:30.214026	suzanebunny87@gmail.com	601169376689	willonna steffie	\N
1452	32098e45-5ca2-4ce8-a9e5-a31eb7541d6f	1	1	\N	Belinda Wong	wongsiawmei2@yahoo.com	60105679749	t	2025-11-08 03:52:39.300452	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "AFORCE REALTY SDN BHD ", "position": "Agent "}	2025-11-08 03:52:18.724919	2025-11-08 03:52:39.301132	wongsiawmei2@yahoo.com	60105679749	belinda wong	\N
1460	18aab70b-3fff-4d0e-b417-beade8eba8ce	1	3	\N	Jowez	\N	60168332793	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Blossom Boxes ", "position": "Manager "}	2025-11-08 04:13:02.917919	2025-11-08 04:13:02.917919	\N	60168332793	jowez	\N
1461	924c384d-a492-44cc-a67c-44a3defd2ab6	1	1	\N	Fadzilah Binti Mohd Fahimi	fadzilah1175@gmail.com	601155004679	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Zee Enterprise ", "position": "-"}	2025-11-08 04:13:28.699732	2025-11-08 04:13:28.699732	fadzilah1175@gmail.com	601155004679	fadzilah binti mohd fahimi	\N
1468	60c58f8c-73b7-4dfe-87cf-2f6172d0602e	1	1	\N	Shaiful Bahri Bin Abidin	cikgushaifulbahri@gmail.com	60138854983	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Aforce realty", "position": "Pre leader"}	2025-11-08 04:27:01.33164	2025-11-08 04:27:01.33164	cikgushaifulbahri@gmail.com	60138854983	shaiful bahri bin abidin	\N
1471	8bfbfe1d-af25-49b1-aa3c-515c54d9512e	1	3	\N	Erica Chung	\N	601163123168	t	2025-11-08 04:41:45.504015	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Erica & Co", "position": "Sole Proprietor"}	2025-11-08 04:41:24.240106	2025-11-08 04:41:45.505047	\N	601163123168	erica chung	\N
1478	9a1c99db-73e6-446e-b3fc-2282abe6a4fa	1	1	\N	Lazario	lazariolai24@gmail.com	601139360744	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Smk kolombong"}	2025-11-08 04:46:47.63104	2025-11-08 04:46:47.63104	lazariolai24@gmail.com	601139360744	lazario	\N
1455	adc80cf8-8fd1-4fa7-a4a1-01ffa9b7b418	1	1	\N	Janice	Janicechong18@gmail.com	60168108709	t	2025-11-08 04:10:14.90246	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Treeline Urban ", "position": "Manager"}	2025-11-08 04:10:14.90246	2025-11-08 04:10:14.90246	janicechong18@gmail.com	60168108709	janice	\N
1484	5f0db516-d149-4512-93e1-97f8bb1c1882	1	1	\N	Iliesviney	07yitongs@gmail.com	60148996044	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "STPM PITAS 2 "}	2025-11-08 05:00:00.191106	2025-11-08 05:00:00.191106	07yitongs@gmail.com	60148996044	iliesviney	\N
1485	96c8f846-e9e3-4b46-ae0c-04b98835789f	1	1	\N	Sherlyn	shersherslayit@gmail.com	60147701709	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SM ALL SAINTS"}	2025-11-08 05:00:40.195283	2025-11-08 05:00:40.195283	shersherslayit@gmail.com	60147701709	sherlyn	\N
1486	213b73d3-2a49-4cf8-b154-3358ef2019ed	1	1	\N	Tia Arise	Itstiaj01@gmail.com	60168159608	t	2025-11-08 05:02:10.248173	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "HARDKHOR FITNESS PLT.", "position": "Co-Founder"}	2025-11-08 05:01:46.779718	2025-11-08 05:02:10.248906	itstiaj01@gmail.com	60168159608	tia arise	\N
1488	e74c2f92-8b21-4c60-93b9-64b9c105bb79	1	1	\N	Brad Lio	liobrad515@gmail.com	60173475895	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Na"}	2025-11-08 05:07:03.230521	2025-11-08 05:07:03.230521	liobrad515@gmail.com	60173475895	brad lio	\N
1489	9b5b3dea-e09a-43db-ada0-b01fdf245185	1	1	\N	Vivian	vivianwong1603@gmail.com	601163859298	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Na"}	2025-11-08 05:07:10.817221	2025-11-08 05:07:10.817221	vivianwong1603@gmail.com	601163859298	vivian	\N
1495	267dd6fe-ce12-414f-9573-9e12fd00c7fe	1	1	\N	Liz	rizu0120@hotmail.com	60135553610	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University of London"}	2025-11-08 05:14:07.305111	2025-11-08 05:14:07.305111	rizu0120@hotmail.com	60135553610	liz	\N
1487	dfa24351-487f-4783-8283-903d94dfe740	1	3	\N	Lai Shu Chen	\N	60178342899	t	2025-11-08 05:17:07.652746	29	1	1	\N	\N	\N	{"role": "Delegate", "company": "Appleoffsprings", "position": "Representative"}	2025-11-08 05:04:11.450232	2025-11-08 05:17:07.653334	\N	60178342899	lai shu chen	\N
1501	35666471-4db5-4bf6-9eab-34563c054025	1	3	\N	Clifford Lee Kah Rong	\N	60168308191	t	2025-11-08 05:26:19.321786	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Menu Lee PLT ", "position": "Assistant"}	2025-11-08 05:26:04.784298	2025-11-08 05:26:19.32245	\N	60168308191	clifford lee kah rong	\N
1502	bf818598-d8fb-4730-9afa-b5bff18a29ff	1	3	\N	Alyssa	\N	60168308199	t	2025-11-08 05:27:12.521826	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "MENU LEE", "position": "Manager"}	2025-11-08 05:26:57.190968	2025-11-08 05:27:12.522468	\N	60168308199	alyssa	\N
1513	4e8f3693-7521-4fa2-9850-60222b536bff	1	1	\N	Velinda Badin	velinda95badin@icloud.com	60135026467	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "LPL ACADEMY"}	2025-11-08 05:41:03.087959	2025-11-08 05:41:03.087959	velinda95badin@icloud.com	60135026467	velinda badin	\N
1516	b3f0039b-8d46-4e05-a69b-d28ea9277593	1	1	\N	Victor	victor.kumar2671@gmail.com	60162220206	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "UMS "}	2025-11-08 05:42:06.077841	2025-11-08 05:42:06.077841	victor.kumar2671@gmail.com	60162220206	victor	\N
1534	1c2f4221-b144-43c8-9a6c-5fec4c2206af	1	3	\N	Baka Alex	\N	60143512298	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Nil", "position": "Nil"}	2025-11-08 06:00:19.810319	2025-11-08 06:00:19.810319	\N	60143512298	baka alex	\N
1539	8e017f1e-3a15-42f0-a753-052ad30b6ba3	1	3	\N	Ana Zarina Binti Mahamud	\N	60128879791	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "MAS Awana Services Sdn Bhd", "position": "HR Executive"}	2025-11-08 06:02:23.678653	2025-11-08 06:02:23.678653	\N	60128879791	ana zarina binti mahamud	\N
1540	1f5c1f2c-794a-421a-8ce7-7cf97cf002ef	1	1	\N	Yong Yee Ling	yeeling2320@gmail.com	60109875336	t	2025-11-08 06:02:25.60455	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "no", "position": "non"}	2025-11-08 06:02:25.60455	2025-11-08 06:02:25.60455	yeeling2320@gmail.com	60109875336	yong yee ling	\N
1566	f64ed2e4-999c-4499-bfba-4b873db36e7f	1	1	\N	Nurzulaikhah	kpopaiko17@gmail.com	60168378082	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Politeknik kk"}	2025-11-08 06:31:15.29076	2025-11-08 06:31:15.29076	kpopaiko17@gmail.com	60168378082	nurzulaikhah	\N
1567	f7fff5ff-36c0-4693-82ea-9f19cca9c73a	1	1	\N	Pang Cheak Yin	Joeypang_82@yahoo.com	60107608248	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Manulife Insurance Berhad", "position": "Insurance agent"}	2025-11-08 06:31:51.721909	2025-11-08 06:31:51.721909	joeypang_82@yahoo.com	60107608248	pang cheak yin	\N
1542	ca653a55-32fe-4e95-a626-ec23ccc6c4b6	1	1	\N	Jamala	Jamalabintikuta@gmail.com	60198805164	t	2025-11-08 06:05:12.873611	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 06:05:12.873611	2025-11-08 06:05:12.873611	jamalabintikuta@gmail.com	60198805164	jamala	\N
1543	0552a0e4-bf64-4291-a035-ac302f455844	1	1	\N	Ozzer Othaman	ozzer7317@gmail.com	60195307033	t	2025-11-08 06:05:27.061522	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:05:27.061522	2025-11-08 06:05:27.061522	ozzer7317@gmail.com	60195307033	ozzer othaman	\N
1569	910e34aa-8605-402a-8a00-9611d290590f	1	1	\N	Arianna	ariannafit@gmail.con	60109523081	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Politeknik"}	2025-11-08 06:32:03.448961	2025-11-08 06:32:03.448961	ariannafit@gmail.con	60109523081	arianna	\N
1570	27e1e3cb-ab52-48d2-91d4-39dc84640ec4	1	1	\N	Bk	nobleblossom55327@gmail.com	60123321448	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Ugo child care", "position": "Principal"}	2025-11-08 06:32:06.715879	2025-11-08 06:32:06.715879	nobleblossom55327@gmail.com	60123321448	bk	\N
1580	a0643094-1d0e-4f8a-bdfc-b4fc099f6034	1	1	\N	Muhammad Afiq Danish Bin Musyiri	danishmusyiri5212@gmail.com	60138548083	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Hehe"}	2025-11-08 06:44:15.537398	2025-11-08 06:44:15.537398	danishmusyiri5212@gmail.com	60138548083	muhammad afiq danish bin musyiri	\N
1592	a104871e-1cf3-4c8a-a627-046bfb3bbe24	1	1	\N	Alvin Lee	alvinlyp0838@gmail.com	601133038371	t	2025-11-08 06:56:39.117774	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "City two property ", "position": "Agent"}	2025-11-08 06:56:21.199524	2025-11-08 06:56:39.118729	alvinlyp0838@gmail.com	601133038371	alvin lee	\N
1598	95cf8fd2-8ead-4bd3-8d16-70004654234f	1	1	\N	Ag Ahmad Bin Mohd Yunus	awangahmad@yahoo.com	60168124883	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "University Malaysia Sabah "}	2025-11-08 07:01:17.583477	2025-11-08 07:01:17.583477	awangahmad@yahoo.com	60168124883	ag ahmad bin mohd yunus	\N
1601	76e930fb-1cde-4527-8e49-613fbad1949d	1	1	\N	Nur Alya Zhafirah Binti Mohammad Fathil	haneezs73@yahoo.com	60128051402	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SK SRI GAYA"}	2025-11-08 07:02:43.39525	2025-11-08 07:02:43.39525	haneezs73@yahoo.com	60128051402	nur alya zhafirah binti mohammad fathil	\N
1605	c15661d5-9a9f-439a-9b31-dc535b223045	1	1	\N	Shafa	norshafawatidarwis@gmail.com	601117765428	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Firm Horizon Sdn Bhd", "position": "Crew"}	2025-11-08 07:04:49.596998	2025-11-08 07:04:49.596998	norshafawatidarwis@gmail.com	601117765428	shafa	\N
1608	722086ee-74c3-4a1d-9d2e-0b1e1432e127	1	1	\N	Eidelweiss Franzel	eidelweissf@gmail.com	601159522312	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University Malaysia Sabah"}	2025-11-08 07:05:13.31053	2025-11-08 07:05:13.31053	eidelweissf@gmail.com	601159522312	eidelweiss franzel	\N
1609	e637d821-e6c9-4181-89e1-61655f08e718	1	1	\N	Nur Azwaizah Dini Ayub	azwaizah@gmail.com	60124417975	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Universiti Malaysia Sabah"}	2025-11-08 07:05:16.250891	2025-11-08 07:05:16.250891	azwaizah@gmail.com	60124417975	nur azwaizah dini ayub	\N
1613	a958d6fc-3d40-4c9e-9344-609fcf1d83e8	1	1	\N	Muhammad Aizam Bin Anwar	muhdaizamanwar@gmail.com	60102874027	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIVERSITI MALAYSIA SABAH"}	2025-11-08 07:05:49.68294	2025-11-08 07:05:49.68294	muhdaizamanwar@gmail.com	60102874027	muhammad aizam bin anwar	\N
1614	8e54949c-e11b-4c12-a109-3950814e18d9	1	1	\N	Azli	mohdazli120902@gmail.com	601111653350	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UITM"}	2025-11-08 07:07:15.734276	2025-11-08 07:07:15.734276	mohdazli120902@gmail.com	601111653350	azli	\N
1615	f35e9727-6ae0-4aca-a803-14909df33095	1	1	\N	Syazlin	syazlinsusilo@gmail.com	60134774733	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-08 07:07:29.00872	2025-11-08 07:07:29.00872	syazlinsusilo@gmail.com	60134774733	syazlin	\N
1696	2b4e7a26-a09a-4d5f-aa95-84af3270a395	1	3	\N	Km	\N	60168308889	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Abc ", "position": "Ketua menteri"}	2025-11-08 08:46:03.236224	2025-11-08 08:46:03.236224	\N	60168308889	km	\N
1626	10efc4c7-4005-4dbe-a89a-3149ad7f44d0	1	1	\N	Jennifer Shih Chai Ying	Jennifer1003@live.com.my	60168802098	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "You Yuan Lai Desserts", "position": "Seller"}	2025-11-08 07:10:56.841081	2025-11-08 07:10:56.841081	jennifer1003@live.com.my	60168802098	jennifer shih chai ying	\N
1630	12f647e6-1bd3-42b4-a56c-9e55818a098a	1	1	\N	Norimah Ismail	Noromahismail86@gmail.com	601116008975	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "N/A"}	2025-11-08 07:15:48.327092	2025-11-08 07:15:48.327092	noromahismail86@gmail.com	601116008975	norimah ismail	\N
1636	0257789c-80e7-43ca-a697-f21d1d119005	1	1	\N	Evylin Ludin	evylinludin367@gmail.com	60108204827	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIVERSITY MALAYSIA SABAH"}	2025-11-08 07:28:31.746546	2025-11-08 07:28:31.746546	evylinludin367@gmail.com	60108204827	evylin ludin	\N
1641	6a3880b3-db32-4980-b92b-042bf690e405	1	1	\N	Sunny Liew Vun Xu	sunnyliewvunxu@gmail.com	60102682929	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Universiti Malaysia Sabah"}	2025-11-08 07:31:42.701491	2025-11-08 07:31:42.701491	sunnyliewvunxu@gmail.com	60102682929	sunny liew vun xu	\N
1643	c3df4583-00e8-4882-a748-fbba749594e4	1	1	\N	Ong Zi Ze	wuongzize1@gmail.com	60102338322	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "universiti malaysia sabah"}	2025-11-08 07:32:06.915985	2025-11-08 07:32:06.915985	wuongzize1@gmail.com	60102338322	ong zi ze	\N
1644	fca817f9-fd62-40fd-afa7-e1fd47f66b70	1	1	\N	Dorothea Justin Moduying	dmjustin89@gmail.comfom	60198225533	t	2025-11-08 07:35:40.630758	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Neobayu Academy of Natural Medicine Sdn Bhd", "position": "Managing Director"}	2025-11-08 07:34:17.251549	2025-11-08 07:35:40.631338	dmjustin89@gmail.comfom	60198225533	dorothea justin moduying	\N
1656	7ea67ca3-6614-40b7-bca8-5b452f70a3aa	1	1	\N	Alvin Ranjywa A Tundim	vventundim@gmail.com	60168798770	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University Malaysia Sabah"}	2025-11-08 07:59:26.976243	2025-11-08 07:59:26.976243	vventundim@gmail.com	60168798770	alvin ranjywa a tundim	\N
1657	19184902-38b9-4959-b9dd-eb03812381e0	1	1	\N	Shini Dev	Toppicksandstreams@gmail.com	6584463247	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-08 07:59:56.228416	2025-11-08 07:59:56.228416	toppicksandstreams@gmail.com	6584463247	shini dev	\N
1659	539346df-23b1-4282-ac2d-1b64eb2a8d9e	1	1	\N	Angelina Nicole Augustine	angelinanicole.a@gmail.com	60163436235	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-08 08:01:18.279414	2025-11-08 08:01:18.279414	angelinanicole.a@gmail.com	60163436235	angelina nicole augustine	\N
1660	5a91b239-e1f0-4e4c-9b08-d80f66d0990b	1	1	\N	Jquez	chocolatecake654321@gmail.com	60135525530	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Kolej Yayasan sabah"}	2025-11-08 08:01:21.459439	2025-11-08 08:01:21.459439	chocolatecake654321@gmail.com	60135525530	jquez	\N
1663	4e56087c-5e01-449a-bef7-ce9d736a9bd0	1	1	\N	Ng Zhao Chi	Darryngzhaochi00@gmail.com	60168408369	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University of Sheffield"}	2025-11-08 08:06:42.403149	2025-11-08 08:06:42.403149	darryngzhaochi00@gmail.com	60168408369	ng zhao chi	\N
1665	3b0effa8-c1a9-4e03-9a53-edddd050d314	1	1	\N	Haiqal Hakimi	hakimihaiqal950@gmail.com	60178646085	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIRAZAK"}	2025-11-08 08:09:34.839334	2025-11-08 08:09:34.839334	hakimihaiqal950@gmail.com	60178646085	haiqal hakimi	\N
1668	e1b422f3-1d15-4a7c-ada7-a7a63787d91a	1	1	\N	Safika Chen	safieqachen@gmail.com	60135422875	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIRAZAK"}	2025-11-08 08:10:44.193089	2025-11-08 08:10:44.193089	safieqachen@gmail.com	60135422875	safika chen	\N
1684	6e529dfc-3916-472b-86da-e46a27df2c89	1	1	\N	Nur Syaqirah	nursyaqirah18@gmail.con	60138262148	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Uitm"}	2025-11-08 08:35:18.415667	2025-11-08 08:35:18.415667	nursyaqirah18@gmail.con	60138262148	nur syaqirah	\N
1686	72c2370a-4b09-4db7-9cf3-95a8afe1237e	1	1	\N	Phoebe Koh Li Jun	ssyuhadahh@gmail.com	60137276167	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Universiti Malaysia Sabah"}	2025-11-08 08:35:33.413526	2025-11-08 08:35:33.413526	ssyuhadahh@gmail.com	60137276167	phoebe koh li jun	\N
1688	f7bf1662-53a3-4ab8-aea7-b9653365bfc0	1	1	\N	Brandon	brandonseowweijian@gmail.com	60102298488	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sttss"}	2025-11-08 08:38:42.19363	2025-11-08 08:38:42.19363	brandonseowweijian@gmail.com	60102298488	brandon	\N
1691	dca8c7d4-33da-48dd-855c-7e0ac1e6070c	1	1	\N	Zhuatizai	zhuatizai@gmail.com	60163500302	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "kkhs"}	2025-11-08 08:40:03.263408	2025-11-08 08:40:03.263408	zhuatizai@gmail.com	60163500302	zhuatizai	\N
1693	f51e87c2-105a-4658-8f9c-c39fa5ad5f52	1	1	\N	Afdhan Ziqri	afdhanziqri@gmail.com	60138131625	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Ums"}	2025-11-08 08:43:03.709059	2025-11-08 08:43:03.709059	afdhanziqri@gmail.com	60138131625	afdhan ziqri	\N
1695	ece5eddd-acbf-41dd-81d5-407ff95435ec	1	1	\N	Nur Hasya Athilah	waja6009@gmail.com	60138600980	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sk sri gaya"}	2025-11-08 08:46:00.401452	2025-11-08 08:46:00.401452	waja6009@gmail.com	60138600980	nur hasya athilah	\N
1698	e46dab2f-1ab9-498a-944b-5d6900f16ce6	1	1	\N	Catherine	cathvung@gmail.com	60168179282	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sfc"}	2025-11-08 08:48:51.924139	2025-11-08 08:48:51.924139	cathvung@gmail.com	60168179282	catherine	\N
1722	c027e38f-8db8-49ac-94f1-869610b44367	1	1	\N	Brendan Lo Zao Loong	0251013@sttss.edu.my	60189080307	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sabah Tshung Tshin secondary school "}	2025-11-09 02:14:11.693549	2025-11-09 02:14:11.693549	0251013@sttss.edu.my	60189080307	brendan lo zao loong	\N
1726	3f2e1f13-3b14-42f5-8c16-35ee2cebca71	1	1	\N	Cindy Hiew Jing	Hiewjing6@gmail.com	60109325255	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cnsweet", "position": "Owner"}	2025-11-09 02:25:55.08678	2025-11-09 02:25:55.08678	hiewjing6@gmail.com	60109325255	cindy hiew jing	\N
1718	ef31881a-9148-45da-a850-e396f94dd013	1	1	\N	Chung Tze Yen	Steven83chung@gmail.com	60162335955	t	2025-11-09 01:46:59.410064	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "STONE DELIMA", "position": "Founder"}	2025-11-09 01:46:59.410064	2025-11-09 01:46:59.410064	steven83chung@gmail.com	60162335955	chung tze yen	\N
1719	2c1d5c4e-516e-4cbe-aaaa-51ad461b339b	1	1	\N	Aloysius Lo	Dcisb2000@gmail.com	60198816562	t	2025-11-09 02:12:10.760177	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Daily Chemical Industries sb", "position": "Director"}	2025-11-09 02:12:10.760177	2025-11-09 02:12:10.760177	dcisb2000@gmail.com	60198816562	aloysius lo	\N
1720	ed8d2b40-565a-4d72-8482-19c8b20f6a3d	1	1	\N	Michael Chong	balannear@gmail.com	60178188299	t	2025-11-09 02:13:02.721575	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Gemilang trading enterprise", "position": "Administration officer"}	2025-11-09 02:13:02.721575	2025-11-09 02:13:02.721575	balannear@gmail.com	60178188299	michael chong	\N
1721	3358a423-586c-446a-849d-374e0c08605e	1	1	\N	Christine Ng	chrisng6360@gmail.com	60168466360	t	2025-11-09 02:13:03.893653	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Daily Chemical Industries Sdn Bhd", "position": "Clerk"}	2025-11-09 02:13:03.893653	2025-11-09 02:13:03.893653	chrisng6360@gmail.com	60168466360	christine ng	\N
1723	a9f32975-4178-4a9b-af30-ffd99743a0aa	1	1	\N	Jason Ong	Pedalshoppe@gmail.com	60198818555	t	2025-11-09 02:20:09.893978	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 02:20:09.893978	2025-11-09 02:20:09.893978	pedalshoppe@gmail.com	60198818555	jason ong	\N
1724	5df86e73-34ee-4fb5-894a-7803d68e6327	1	1	\N	Elaine Koh	legendwave393@gmail.com	60167700393	t	2025-11-09 02:24:08.245147	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Legend wave tours & travel sdn bhd ", "position": "Directot"}	2025-11-09 02:24:08.245147	2025-11-09 02:24:08.245147	legendwave393@gmail.com	60167700393	elaine koh	\N
1725	adcf687a-1d5b-43c1-b5ef-3e834f0d8f11	1	1	\N	Ray	Ray722@qq.com	60168300454	t	2025-11-09 02:24:11.70812	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Tommys place ", "position": "Manager"}	2025-11-09 02:24:11.70812	2025-11-09 02:24:11.70812	ray722@qq.com	60168300454	ray	\N
1727	ca4a74e9-7a94-4c99-bf24-b676a4018468	1	1	\N	Lizz Jing	cindyhiew198@gmail.com	60109590385	t	2025-11-09 02:27:43.836484	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "visitor", "position": "visitor"}	2025-11-09 02:27:43.836484	2025-11-09 02:27:43.836484	cindyhiew198@gmail.com	60109590385	lizz jing	\N
1728	891c3db9-c12f-4a5a-95fe-250497d4ed86	1	1	\N	Chungjiafoh	chungjiafoh@gmail.com	601116181682	t	2025-11-09 02:30:23.721373	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "visitor", "position": "visitor"}	2025-11-09 02:30:23.721373	2025-11-09 02:30:23.721373	chungjiafoh@gmail.com	601116181682	chungjiafoh	\N
1729	4a9e2888-eb7c-462c-a90d-1ccefefc5183	1	1	\N	Nurci Yati Madius	Nurciyati24@gmail.com	60145588345	t	2025-11-09 02:31:19.706902	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 02:31:19.706902	2025-11-09 02:31:19.706902	nurciyati24@gmail.com	60145588345	nurci yati madius	\N
1730	915dd356-813f-4524-93ed-fd9e96077764	1	1	\N	Jas Chung	jasauto1766@gmail.com	60168831766	t	2025-11-09 02:33:55.601501	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "visitor", "position": "visitor"}	2025-11-09 02:33:55.601501	2025-11-09 02:33:55.601501	jasauto1766@gmail.com	60168831766	jas chung	\N
1731	c77b2c5c-4ac6-4c0d-8e7d-e9548527909a	1	1	\N	Nur Hidayah Binti Omar	Canaistory19@gmail.com	60176792019	t	2025-11-09 02:38:15.26706	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Canai story", "position": "Owner"}	2025-11-09 02:38:15.26706	2025-11-09 02:38:15.26706	canaistory19@gmail.com	60176792019	nur hidayah binti omar	\N
1741	21403516-3ed7-4b95-8af6-c7f2667a2968	1	1	\N	Esther Lyssa	lelaislys@gmail.com	601110101609	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SM MAKTAB SABAH"}	2025-11-09 02:55:58.953069	2025-11-09 02:55:58.953069	lelaislys@gmail.com	601110101609	esther lyssa	\N
1742	8fff4ad5-9e4a-4292-8923-0cce136e8d64	1	1	\N	Ikin	nurashikin0299@gmail.com	60163027454	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-09 03:10:59.732787	2025-11-09 03:10:59.732787	nurashikin0299@gmail.com	60163027454	ikin	\N
1744	e78489ea-b9a8-4812-8daa-c7b39b834382	1	1	\N	Maggie	Meigee6366@gmail.com	60168319917	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sunway "}	2025-11-09 03:26:46.174451	2025-11-09 03:26:46.174451	meigee6366@gmail.com	60168319917	maggie	\N
1745	e7d33899-1782-402f-b235-4b8de8337a0b	1	1	\N	Angela	f.angela.jeafry@gmail.com	601125280789	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "SJKC LOK YUK MENGGATAL"}	2025-11-09 03:27:30.382814	2025-11-09 03:27:30.382814	f.angela.jeafry@gmail.com	601125280789	angela	\N
1746	6b26ee48-9223-4270-9a8c-7bf204aef4c5	1	1	\N	Norhafizah Syazawani Binti Abd Halim	Norhafizah.syazawani@gmail.com	601111427200	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIVERSITY COLLEGE SABAH FOUNDATION "}	2025-11-09 03:44:18.367373	2025-11-09 03:44:18.367373	norhafizah.syazawani@gmail.com	601111427200	norhafizah syazawani binti abd halim	\N
1747	67e2aff2-bd4e-445c-b287-943a6e858f25	1	1	\N	Ika Yusriani	Ikayusriani1007@gmail.com	60102856469	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University college sabah foundation"}	2025-11-09 03:44:28.095703	2025-11-09 03:44:28.095703	ikayusriani1007@gmail.com	60102856469	ika yusriani	\N
1748	00a81e49-4121-43c3-bdf6-8b4fc4fb2f07	1	1	\N	Siti Natasyah Abdullah	natasyahegypt@gmail.com	60176471686	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University college Sabah foundation "}	2025-11-09 03:44:31.758589	2025-11-09 03:44:31.758589	natasyahegypt@gmail.com	60176471686	siti natasyah abdullah	\N
1749	81acc05f-c437-462a-99e7-b29bbbb1b18f	1	1	\N	Regina Teoh	reginateoh05@gmail.com	601151829035	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UCSF"}	2025-11-09 03:44:39.32794	2025-11-09 03:44:39.32794	reginateoh05@gmail.com	601151829035	regina teoh	\N
1750	5cabb242-9bec-4033-bcfd-914bddfc0fc5	1	1	\N	Nordeana Wildani	dean98523@gmail.com	60102665730	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "university college sabah foundation"}	2025-11-09 03:44:55.840002	2025-11-09 03:44:55.840002	dean98523@gmail.com	60102665730	nordeana wildani	\N
1751	5a5468d9-8fa0-4af6-baa0-c2eafd9c4381	1	1	\N	Nur Iqa Izzati Binti Morsain	izzatimorsaini@gmail.com	60192200812	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "University College Sabah Foundation"}	2025-11-09 03:45:18.574419	2025-11-09 03:45:18.574419	izzatimorsaini@gmail.com	60192200812	nur iqa izzati binti morsain	\N
1757	eb765ae6-4f44-469f-8fb4-ebfa580c7f77	1	1	\N	Daniel Hairy	danzen7216@gmail.com	601169228837	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Pusat Tingkatan Enam Maktab Sabah"}	2025-11-09 03:54:32.565704	2025-11-09 03:54:32.565704	danzen7216@gmail.com	601169228837	daniel hairy	\N
1758	3fc67721-2c71-43d8-a1b6-7ce36cc182c1	1	1	\N	Abdul Hafiz Bin Sapirin@safrin	hafizsapirin@gmail.com	60104254356	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Pusat Tingkatan Enam Maktab Sabah"}	2025-11-09 03:54:47.957378	2025-11-09 03:54:47.957378	hafizsapirin@gmail.com	60104254356	abdul hafiz bin sapirin@safrin	\N
1759	f1d5cb7c-a63f-48cf-b276-7520a57d49b8	1	1	\N	Ashraf Hakimi	hakimiashraf02@gmail.com	60146037407	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sm Maktab Sabah"}	2025-11-09 03:54:54.443642	2025-11-09 03:54:54.443642	hakimiashraf02@gmail.com	60146037407	ashraf hakimi	\N
1760	d76c7848-daf5-4d7b-9c71-7f1f777ea597	1	1	\N	Arish Azami Bin Bunsu	berubo0698@gmail.com	60193510117	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "pusat tingkatan enam maktab sabah"}	2025-11-09 03:54:54.562598	2025-11-09 03:54:54.562598	berubo0698@gmail.com	60193510117	arish azami bin bunsu	\N
1761	177011a6-5e0e-4e16-9e62-509ac4bda063	1	1	\N	Cyril Ann	nnaliryc06@gmail.com	60105835317	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sabah College"}	2025-11-09 03:55:13.149284	2025-11-09 03:55:13.149284	nnaliryc06@gmail.com	60105835317	cyril ann	\N
1762	1fa8264c-9e06-46fd-a28d-fc39b7b713bc	1	1	\N	Leeza Nur Maisarah Binti Roslee	lzmaisarah06@gmail.com	60195089410	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Pusat Tingkatan Enam Maktab Sabah"}	2025-11-09 03:55:33.72608	2025-11-09 03:55:33.72608	lzmaisarah06@gmail.com	60195089410	leeza nur maisarah binti roslee	\N
1768	7581fe0e-d3cf-4e5a-85ef-0d781b51923e	1	1	\N	Nabilah Syamilah	nabilahsyamilah@gmail.com	601111538862	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG GAYA"}	2025-11-09 04:01:01.678882	2025-11-09 04:01:01.678882	nabilahsyamilah@gmail.com	601111538862	nabilah syamilah	\N
1769	75bd0171-fb06-4bb1-b409-822bf877c462	1	1	\N	Nisa Imejn	nisaimien328@gmail.com	601125494387	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG GAYA"}	2025-11-09 04:01:04.927304	2025-11-09 04:01:04.927304	nisaimien328@gmail.com	601125494387	nisa imejn	\N
1772	45aa920b-52b3-4e73-8864-ad7d9376c8c1	1	1	\N	Nigel	nigelthu99@gmail.com	60168490087	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "RiamTec"}	2025-11-09 04:05:10.065723	2025-11-09 04:05:10.065723	nigelthu99@gmail.com	60168490087	nigel	\N
1773	2a018e02-ccda-4e95-8283-a0f995479cd8	1	1	\N	Natalie	nattt0002@gmail.com	60134818328	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Ati"}	2025-11-09 04:05:12.10553	2025-11-09 04:05:12.10553	nattt0002@gmail.com	60134818328	natalie	\N
1776	bb237935-3bba-44e5-aa78-168f733d0d7b	1	1	\N	Lukie	yedsyed13@gmail.com	60134188343	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "SMKA KOTA KINABALU"}	2025-11-09 04:06:23.329409	2025-11-09 04:06:23.329409	yedsyed13@gmail.com	60134188343	lukie	\N
1777	60dab437-e2fc-4ff3-b929-26ee0b5083b3	1	1	\N	Jay Dexter Jeffrey	jaydexter8888@gmail.com	601126687166	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Almacrest International College "}	2025-11-09 04:06:34.825771	2025-11-09 04:06:34.825771	jaydexter8888@gmail.com	601126687166	jay dexter jeffrey	\N
1778	7ace0026-cf97-4962-828d-28f973a7e1c2	1	1	\N	Mahfuz	mahfuzsuhaimi20@hmail.com	60188720123	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "Smkakk"}	2025-11-09 04:06:35.710018	2025-11-09 04:06:35.710018	mahfuzsuhaimi20@hmail.com	60188720123	mahfuz	\N
1779	4a468c79-1fe4-4781-86f0-f1f359d6637f	1	1	\N	Ahmad Zulhilmi	ahmadazu97@gmail.com	60174369283	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SMK Agama Kota Kinabalu"}	2025-11-09 04:06:46.83428	2025-11-09 04:06:46.83428	ahmadazu97@gmail.com	60174369283	ahmad zulhilmi	\N
1781	b8822119-c76a-45e4-8b57-2451df52b91e	1	1	\N	Putri A	aminahbalqis0607@gmail.com	601151115709	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "MAKTAB SABAH"}	2025-11-09 04:06:54.285989	2025-11-09 04:06:54.285989	aminahbalqis0607@gmail.com	601151115709	putri a	\N
1782	4dcd8b13-cff0-4c5e-95b7-6939c1b98fa1	1	1	\N	Jason Liew	dcjason34@gmail.com	60142016279	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Almacrest international college"}	2025-11-09 04:07:00.265072	2025-11-09 04:07:00.265072	dcjason34@gmail.com	60142016279	jason liew	\N
1783	85ffb798-675f-49bc-beea-a31d1433fc3f	1	1	\N	Nur Ain Rindiani Binti Abdul Basah	ainrindiani25@gmail.com	601139071403	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Almacrest international college "}	2025-11-09 04:07:06.624779	2025-11-09 04:07:06.624779	ainrindiani25@gmail.com	601139071403	nur ain rindiani binti abdul basah	\N
1786	a34cffa7-d0ba-4efe-aa5f-c17fc63f1331	1	1	\N	Syahiran	tuankucrseven@gmail.com	60133298946	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Smk agama kota kinabalu"}	2025-11-09 04:07:38.747218	2025-11-09 04:07:38.747218	tuankucrseven@gmail.com	60133298946	syahiran	\N
1788	e7b88dcb-c833-406b-bbcd-5d5c6f2d5d3a	1	1	\N	Putri Maisyarah	maisyarahputri783@gmail.com	60109091175	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Almacrest international collage"}	2025-11-09 04:08:22.417538	2025-11-09 04:08:22.417538	maisyarahputri783@gmail.com	60109091175	putri maisyarah	\N
1789	0a422fcf-e90a-4d68-b07e-bff452828b76	1	1	\N	Betsy Vine	raybe2025@gmail.com	60128666808	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "KOLEJ KOMUNITI PENAMPANG"}	2025-11-09 04:09:32.487688	2025-11-09 04:09:32.487688	raybe2025@gmail.com	60128666808	betsy vine	\N
1790	ebe09a10-4484-42c4-b6ea-bf49739ae24a	1	1	\N	Jurafidah Rafli	fiedahraflie@gmail.com	601131717338	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Almacrest international college "}	2025-11-09 04:09:39.666518	2025-11-09 04:09:39.666518	fiedahraflie@gmail.com	601131717338	jurafidah rafli	\N
1791	a3dc6a31-86db-40fb-9427-8b9776bd59da	1	1	\N	Siti Nur Natasha Binti Sultan	natashasitinur84@gmail.com	60143796547	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "ALMACREST INTERNATIONAL COLLEGE "}	2025-11-09 04:09:40.140483	2025-11-09 04:09:40.140483	natashasitinur84@gmail.com	60143796547	siti nur natasha binti sultan	\N
1801	9cb82864-99c8-4c36-a89a-ba7d2ffd3c4e	1	1	\N	Nur Atiqah Binti Ihsan @ Hasni	nuratiqahihsan@gmail.com	60133724342	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-09 04:14:01.931383	2025-11-09 04:14:01.931383	nuratiqahihsan@gmail.com	60133724342	nur atiqah binti ihsan @ hasni	\N
1802	e52d5f27-1ec7-4cc1-9326-f8a1761e23d3	1	1	\N	Puteri Nur Iffa Binti Ahmad Fauzi	iffanurfauzi007@gmail.com	60146174817	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "smk putatan"}	2025-11-09 04:14:19.909632	2025-11-09 04:14:19.909632	iffanurfauzi007@gmail.com	60146174817	puteri nur iffa binti ahmad fauzi	\N
1804	73d2737a-8095-4ad0-ae5f-0a8cea5e04bb	1	1	\N	Puteri Nur Balqis	puterifauzi7@gmail.com	601125387193	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Smk Putatan "}	2025-11-09 04:14:55.460466	2025-11-09 04:14:55.460466	puterifauzi7@gmail.com	601125387193	puteri nur balqis	\N
1806	9a5cc3ef-e0bd-402c-a5ed-3f448cbbdc0c	1	1	\N	Ampuan Siti Zulaiqa Binti Ibrahim	sitizulaiqa78@gmail.com	601167896219	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG GAYA"}	2025-11-09 04:15:37.61551	2025-11-09 04:15:37.61551	sitizulaiqa78@gmail.com	601167896219	ampuan siti zulaiqa binti ibrahim	\N
1807	6ce6c784-f76d-48a8-8bf4-6882721736ee	1	1	\N	Anis	anisumai05@gmail.com	60174157375	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG"}	2025-11-09 04:15:38.677909	2025-11-09 04:15:38.677909	anisumai05@gmail.com	60174157375	anis	\N
1810	11af170b-ebc0-4fab-8763-653857498b82	1	1	\N	Marina	marinamaranih@gmail.com	60199049304	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG KAMPUS GAYA KOTA KINABALU"}	2025-11-09 04:16:05.089791	2025-11-09 04:16:05.089791	marinamaranih@gmail.com	60199049304	marina	\N
1815	aaf31da6-cade-4243-919f-a1dde28b3770	1	1	\N	Hartini Binti Asimin	tinismats@gmail.com	60109596983	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "SMKA Tun Ahmadshah"}	2025-11-09 04:24:22.98684	2025-11-09 04:24:22.98684	tinismats@gmail.com	60109596983	hartini binti asimin	\N
1816	0a16a734-707d-4e86-9bac-93391601269b	1	1	\N	Harliana Binti Mohd Arifin	harlianamohdarifin@yahoo.com	60126326283	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "SMKA TUN AHMADSHAH"}	2025-11-09 04:24:59.918337	2025-11-09 04:24:59.918337	harlianamohdarifin@yahoo.com	60126326283	harliana binti mohd arifin	\N
1819	9348b455-81e3-409a-8aa1-8b115c3f7478	1	1	\N	Muhammad Arif Naufal Bin Noorizan	Arifnaufalmy@gmail.com	60193531977	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Ipg Kampus Gaya"}	2025-11-09 04:27:38.876205	2025-11-09 04:27:38.876205	arifnaufalmy@gmail.com	60193531977	muhammad arif naufal bin noorizan	\N
1832	17c63d8f-5b59-4fb0-b650-ca73ce3bc45b	1	1	\N	Muhammad Hilmi Azmi	hilmiazmi100@gmail.com	601111986066	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG KAMPUS GAYA"}	2025-11-09 04:31:25.478255	2025-11-09 04:31:25.478255	hilmiazmi100@gmail.com	601111986066	muhammad hilmi azmi	\N
1834	2b65dc81-794b-4eb5-8429-46d4e82855f3	1	1	\N	Mohamad Zairul	mdzairul06@gmail.com	601112902800	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "IPG Kent Tuaran"}	2025-11-09 04:31:49.918033	2025-11-09 04:31:49.918033	mdzairul06@gmail.com	601112902800	mohamad zairul	\N
1837	3a3430b6-a941-4809-9cf8-c800cdcc46e7	1	1	\N	Awangku Mohammad Fahmi	awangfahmi06@gmail.com	60174704544	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-09 04:34:44.104947	2025-11-09 04:34:44.104947	awangfahmi06@gmail.com	60174704544	awangku mohammad fahmi	\N
1838	2cad51f1-18a6-45b6-bbba-d20effa0494d	1	1	\N	Mohammad Amiruddin Bin Rosman	meeruddin02@gmail.com	601116317115	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UNIRAZAK"}	2025-11-09 04:35:05.118641	2025-11-09 04:35:05.118641	meeruddin02@gmail.com	601116317115	mohammad amiruddin bin rosman	\N
1839	078d52c7-fad5-4a19-90c8-a9be45b38312	1	1	\N	Muhammad Affiq Bin Saharuddin	affiqmyself@gmail.com	60146940084	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UiTM Cawangan Sabah "}	2025-11-09 04:35:08.311882	2025-11-09 04:35:08.311882	affiqmyself@gmail.com	60146940084	muhammad affiq bin saharuddin	\N
1841	f2173047-d990-479e-a1cd-b866ede6091e	1	1	\N	Asya Athirah Binti Yusdi	Asyaathegreat@gmail.com	60103850667	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "MRSM KOTA KINABALU"}	2025-11-09 04:35:37.768137	2025-11-09 04:35:37.768137	asyaathegreat@gmail.com	60103850667	asya athirah binti yusdi	\N
1844	fa957130-0e62-4a9e-8ddd-249050bfc2d7	1	1	\N	Zubi	zzzubiii13@gmail.com	60104519680	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "tingkatan enam maktab sabah"}	2025-11-09 04:36:52.957034	2025-11-09 04:36:52.957034	zzzubiii13@gmail.com	60104519680	zubi	\N
1845	167e76c9-7547-491b-b37c-50966b620623	1	1	\N	Aarey	xooos1107@gmail.com	60166812542	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SIXTH FORM CENTRE SABAH COLLEGE"}	2025-11-09 04:38:43.720798	2025-11-09 04:38:43.720798	xooos1107@gmail.com	60166812542	aarey	\N
1846	9e8f0625-5f74-4103-8d5c-53db54988a90	1	1	\N	Aisha Nawal	crowbeezz@gmail.com	601163090990	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Pusat tingkatan enam maktab sabah"}	2025-11-09 04:39:43.492555	2025-11-09 04:39:43.492555	crowbeezz@gmail.com	601163090990	aisha nawal	\N
1864	8a434ac6-00b1-43ca-90a9-686da0c1d894	1	1	\N	Alexsandra Lee Jia Ying	alexsandra092907@gmail.com	601112605855	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Unitar"}	2025-11-09 05:10:04.973079	2025-11-09 05:10:04.973079	alexsandra092907@gmail.com	601112605855	alexsandra lee jia ying	\N
1866	8edf5998-ed51-4886-b399-e387a3ed2d73	1	1	\N	Raiyre	raiyre0228@gmail.com	60135456086	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-09 05:11:14.891075	2025-11-09 05:11:14.891075	raiyre0228@gmail.com	60135456086	raiyre	\N
1870	fe815b7c-e8d7-42ed-affd-21fe708db69f	1	1	\N	Aroha	harajukuviolet@gmail.com	60143270720	f	\N	\N	0	1	\N	\N	\N	{"role": "Lecturer", "company": "Kuitho"}	2025-11-09 05:19:46.57349	2025-11-09 05:19:46.57349	harajukuviolet@gmail.com	60143270720	aroha	\N
1871	437cd3b1-ea49-4acf-bf39-68734b4e5eab	1	1	\N	Rozaline	rozalinedikul@yahoo.com.my	60145609567	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "NA"}	2025-11-09 05:19:53.361567	2025-11-09 05:19:53.361567	rozalinedikul@yahoo.com.my	60145609567	rozaline	\N
1879	327f7192-a52b-4a68-8a02-77bfc568e71a	1	1	\N	Nancy	nancy.yee3223@gmail.com	60165879898	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Na"}	2025-11-09 05:28:44.226567	2025-11-09 05:28:44.226567	nancy.yee3223@gmail.com	60165879898	nancy	\N
1887	d23e15b3-ed38-4b03-a930-e5a90d8e5be9	1	1	\N	Harith Zahran	harith.helminazrin@gmail.com	60138519971	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "North Borneo University College"}	2025-11-09 05:40:31.806265	2025-11-09 05:40:31.806265	harith.helminazrin@gmail.com	60138519971	harith zahran	\N
1888	fb1a17cf-7111-4da3-9660-d2cea04ed715	1	1	\N	Ariqah	ariqahnblla@gmail.com	60162307207	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "UMS"}	2025-11-09 05:42:30.824457	2025-11-09 05:42:30.824457	ariqahnblla@gmail.com	60162307207	ariqah	\N
1889	91396430-28c3-4a7b-9007-b5e7927de40f	1	1	\N	Ma Yuet Ting	yuetting17@gmail.com	60108298878	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sm shan tao"}	2025-11-09 05:43:13.088958	2025-11-09 05:43:13.088958	yuetting17@gmail.com	60108298878	ma yuet ting	\N
1890	36aabfd7-9ce7-4a2c-a549-5127e4975d19	1	1	\N	Ava	avachloe831@gmail.com	60128326313	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Sm shantao"}	2025-11-09 05:43:13.413057	2025-11-09 05:43:13.413057	avachloe831@gmail.com	60128326313	ava	\N
1896	09fb16fe-0c90-454b-a89d-48cb6052e097	1	1	\N	Amira Sophea	amirasophea47@gmail.com	60128131205	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "ilp kk"}	2025-11-09 05:50:40.186835	2025-11-09 05:50:40.186835	amirasophea47@gmail.com	60128131205	amira sophea	\N
1899	3390ed12-1272-4cf7-8778-60b93c8148a7	1	1	\N	Amelia Sophea	ameliasophea195@gmail.com	601137163241	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "lok yuk"}	2025-11-09 05:52:00.736161	2025-11-09 05:52:00.736161	ameliasophea195@gmail.com	601137163241	amelia sophea	\N
1907	7c04bb57-be9f-414e-a8f2-b32f76bff1b8	1	1	\N	Lin	zhelin0906@gmail.com	60123612089	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "SMLY"}	2025-11-09 06:12:17.510565	2025-11-09 06:12:17.510565	zhelin0906@gmail.com	60123612089	lin	\N
1916	b8ccd2c1-d903-49cd-ac1a-4a487b8c68d2	1	1	\N	Leong On Kei	onkei9866@gmail.com	60147816023	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "lok yuk"}	2025-11-09 06:15:56.438152	2025-11-09 06:15:56.438152	onkei9866@gmail.com	60147816023	leong on kei	\N
1917	e2ca8398-cb93-4d9f-86e7-2b47bac2e9c1	1	1	\N	Foo Kui Ching	Kuichingfoo@gmail.com	60168350783	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "No"}	2025-11-09 06:15:57.138043	2025-11-09 06:15:57.138043	kuichingfoo@gmail.com	60168350783	foo kui ching	\N
1950	2c79ea51-856c-4b09-b770-32b03ed01673	1	1	\N	Noor Azahrinah Binti Mohd Syum	evanatasah05@gmail.com	60162696070	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Evana kitchen", "position": "Manager"}	2025-11-09 07:15:01.787118	2025-11-09 07:15:01.787118	evanatasah05@gmail.com	60162696070	noor azahrinah binti mohd syum	\N
1966	4b5b1698-0a03-404c-a5ec-4041e6bca14b	1	1	\N	Fazree Shairul	fazreeshairulsuhaimin@gmail.com	60129398415	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "Maktab sabah"}	2025-11-09 07:42:08.141025	2025-11-09 07:42:08.141025	fazreeshairulsuhaimin@gmail.com	60129398415	fazree shairul	\N
1968	27041e88-fa2c-4f82-a277-d5f1b7be82eb	1	1	\N	Aleyi Tsen Lojiwin	aleyilojiwin@gmail.com	601160839844	f	\N	\N	0	1	\N	\N	\N	{"role": "Student", "company": "North Borneo University College "}	2025-11-09 07:43:09.483216	2025-11-09 07:43:09.483216	aleyilojiwin@gmail.com	601160839844	aleyi tsen lojiwin	\N
1969	7469fed8-6833-46e3-bdc7-271d7e17226c	1	1	\N	Kathleen Lee	kathleen1410@hotmail.com	60168801069	t	2025-11-09 07:45:48.040928	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Borneo top", "position": "Admin"}	2025-11-09 07:45:48.040928	2025-11-09 07:45:48.040928	kathleen1410@hotmail.com	60168801069	kathleen lee	\N
2006	725e6906-eddd-44c1-b836-8e8b31916c8a	1	1	\N	Putriraisham	Putriraisham@gmail.com	601124479625	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Rainamas kedai runcit", "position": "Promoter"}	2025-11-09 08:27:22.43714	2025-11-09 08:27:22.43714	putriraisham@gmail.com	601124479625	putriraisham	\N
2007	dfd795ba-c5a6-4cfa-a000-e7839023e185	1	1	\N	ᴀᴢᴜʀɪ	Azuri@gmail.com	601133396627	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "ʀᴀɪᴍᴀs", "position": "ᴘᴇɴᴊᴀɢᴀ"}	2025-11-09 08:28:35.774485	2025-11-09 08:28:35.774485	azuri@gmail.com	601133396627	ᴀᴢᴜʀɪ	\N
2008	aa05add8-2300-47a0-b2ec-2f48f9268b24	1	1	\N	Lincoln	Isaac55king55@gmail.com	60138673586	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "Baker Tilly Lsc Plt", "position": "audit associate"}	2025-11-09 08:30:29.90749	2025-11-09 08:30:29.90749	isaac55king55@gmail.com	60138673586	lincoln	\N
2015	b0fc6cbe-5f9d-4245-b1c4-df1a6b5d0a01	1	1	\N	Edee Bin Long	evanatasah05@gmail.com	60162696070	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "Evana kitchen", "position": "Assistent"}	2025-11-09 08:42:21.460153	2025-11-09 08:42:21.460153	evanatasah05@gmail.com	60162696070	edee bin long	\N
2017	0fa22f00-c17c-4a30-819f-b567098a6e9d	1	1	\N	Jowie	jowiesam87@hotmail.com	60168250722	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "na", "position": "na"}	2025-11-09 09:14:57.017568	2025-11-09 09:14:57.017568	jowiesam87@hotmail.com	60168250722	jowie	\N
1410	067eba2c-3ec0-4950-b5e0-f432a583dfa4	1	1	\N	Chin Kui Jin	chinkuijin@gmail.com	60168303468	t	2025-11-08 03:11:24.846572	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "-", "position": "-"}	2025-11-08 03:11:10.085624	2025-11-11 05:32:38.913725	chinkuijin@gmail.com	60168303468	chin kui jin	\N
2019	c842833a-d6bd-45c6-8e1f-46982caea004	1	3	\N	Sp Teo	\N	\N	t	2025-11-11 06:00:59.102147	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH PLUMBER", "position": "VICE PRESIDENT"}	2025-11-11 06:00:49.641034	2025-11-11 06:00:59.102883	\N	\N	sp teo	\N
2020	938dd135-1179-422f-99ac-78248a4d5df2	1	1	\N	Malvina Flant	\N	\N	t	2025-11-11 06:10:28.55424	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "POIC SABAH SDN BHD", "position": "HEAD OF CORPORATE COMMUNICATONS"}	2025-11-11 06:10:20.794665	2025-11-11 06:10:52.701116	\N	\N	malvina flant	\N
1541	7227a13e-4a08-4bd2-ae06-9584c7bbb0b7	1	3	\N	Melvin Mau Chi Chiin	\N	60143720936	t	2025-11-11 06:13:44.200905	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Eon auto mart sdn bhd", "position": "Salesman"}	2025-11-08 06:02:55.898303	2025-11-11 06:13:44.201701	\N	60143720936	melvin mau chi chiin	\N
2021	4c31fb05-055b-466d-ac6c-3c15c14706db	1	1	\N	Norita Binti Tani	\N	\N	t	2025-11-11 06:16:03.923776	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KEPKAS", "position": "SENIOR OFFICER"}	2025-11-11 06:14:55.574064	2025-11-11 06:16:03.924708	\N	\N	norita binti tani	\N
813	61805f55-7659-4270-a5f8-0dd953fae458	1	1	\N	Putera Emy Ezwan Shah Bin Rashideen	puteraemyezwanshah@gmail.com	60128182203	t	2025-11-07 02:50:24.810388	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Agrobis Integrated Trading", "position": "Managing Partner"}	2025-11-07 02:50:03.776521	2025-11-11 06:18:49.376163	puteraemyezwanshah@gmail.com	60128182203	putera emy ezwan shah bin rashideen	\N
2022	4ae332a7-0034-4dfd-bde3-6ed47d10f73b	1	1	\N	Cayenne	\N	\N	t	2025-11-11 06:19:42.927397	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Cuckoo International", "position": "Sales Agent"}	2025-11-11 06:19:31.712982	2025-11-11 06:19:42.92801	\N	\N	cayenne	\N
2000	ef3ecf4b-61ba-425f-a158-08e0157361b1	1	1	\N	Mohd Sidek	mohammedsidek1970@gmail.com	60105122404	t	2025-11-09 08:21:18.700416	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 08:21:18.700416	2025-11-09 08:21:18.700416	mohammedsidek1970@gmail.com	60105122404	mohd sidek	\N
898	e922a854-2b8d-42dc-b2e3-841dd5936598	1	1	\N	Joel Wong Kwang Chao	Joelwongdml@gmail.com	60168223197	t	2025-11-07 04:07:24.500044	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "DML PRODUCTS (EAST MALAYSIA) SDN BHD", "position": "SALES & MARKETING", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:06:54.466528	2025-11-11 23:54:13.239556	joelwongdml@gmail.com	60168223197	joel wong kwang chao	\N
2023	7dfc6296-561b-4db7-8f9f-1ee46278ae28	1	1	\N	Asne Binti Ramin	\N	\N	t	2025-11-11 06:20:33.959143	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SABAH CREDIT CORPORATION", "position": "STAFF", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 06:20:21.847663	2025-11-12 00:36:59.139583	\N	\N	asne binti ramin	\N
2027	c3472b48-fa3f-4add-bf60-fcaf8ce124ad	1	1	\N	Denny Kindamin	\N	\N	t	2025-11-11 07:01:22.980273	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "VANDER ATELIER", "position": "CO FOUNDER"}	2025-11-11 07:01:10.696731	2025-11-11 07:01:22.981389	\N	\N	denny kindamin	\N
2035	6e9f2ba1-27ff-49f0-927f-b67b27b85782	1	1	\N	Ahmad Amirul	\N	\N	t	2025-11-11 07:16:38.23098	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "KINABALU HANDMADE CHOCOLATE", "position": "MANAGER"}	2025-11-11 07:16:13.29771	2025-11-11 07:16:38.231746	\N	\N	ahmad amirul	\N
71	a20ed3ba-78c5-49a3-959a-4a7971ad98a8	1	1	\N	Evander Francis	\N	019-832 8394	t	2025-11-07 02:28:29.745297	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "Vander Atelier - Clothing (Sabah Motif)", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:46:46.981701	2025-11-11 07:02:15.950224	\N	0198328394	evander francis	\N
757	6abee64f-e6d2-4aef-9332-a427efdf3a2f	1	1	\N	Chong Fui Ling	elaine@scaleup.com.my	60128289267	t	2025-11-11 07:03:46.327974	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "Scaleup Corporate Services Sdn Bhd ", "position": "Company Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:18:19.377821	2025-11-11 07:03:46.32857	elaine@scaleup.com.my	60128289267	chong fui ling	\N
2028	3788e6b3-8ce4-4096-a458-f6a5783f8511	1	1	\N	Brenda Londoh	\N	\N	t	2025-11-11 07:04:57.074104	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "LON & GIN", "position": "DIRECTOR"}	2025-11-11 07:04:47.719447	2025-11-11 07:04:57.074969	\N	\N	brenda londoh	\N
2029	8a5d04d9-3629-40ad-976b-73d4016be6e8	1	1	\N	Ben	\N	\N	t	2025-11-11 07:05:49.540541	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "LON & GIN", "position": "STAFF"}	2025-11-11 07:05:36.617181	2025-11-11 07:05:49.541298	\N	\N	ben	\N
2030	f5fdc098-c950-4093-9e12-4e22ef1bb23f	1	1	\N	Esther Chong	\N	\N	t	2025-11-11 07:08:09.595172	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "NAM HENG SAFETY GLASS (SABAH) SDN BHD", "position": "CONSULTANT"}	2025-11-11 07:07:29.022639	2025-11-11 07:08:09.595856	\N	\N	esther chong	\N
780	72faea49-771c-4049-ba70-775c6b5c18b9	1	1	\N	Bryant Theutama	\N	0168434539	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "NAM HENG SAFETY GLASS (SABAH) SDN BHD", "position": "HR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:46:51.648201	2025-11-11 07:08:46.730083	\N	0168434539	bryant theutama	\N
2031	6c9a7a92-de0c-4274-bf84-99e530960a73	1	1	\N	Haskent	\N	\N	t	2025-11-11 07:10:16.009339	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "SMK ST PETER TELIPOK", "position": "STUDENT"}	2025-11-11 07:10:01.962147	2025-11-11 07:10:16.009966	\N	\N	haskent	\N
2032	fdec394b-394b-4492-895c-966556e2b60a	1	1	\N	Iwan Zurfazlie	\N	\N	t	2025-11-11 07:11:27.713308	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "WSG GROUP", "position": "SALES EXECUTIVE"}	2025-11-11 07:11:15.300655	2025-11-11 07:11:27.714006	\N	\N	iwan zurfazlie	\N
880	07a82056-504b-412c-910a-c084ccf34580	1	1	\N	Winnie Chin	wsggroup@yahoo.com	60168312946	t	2025-11-07 03:47:50.773317	30	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG GROUP", "position": "PA", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 03:47:35.972891	2025-11-11 07:11:43.548551	wsggroup@yahoo.com	60168312946	winnie chin	\N
2033	a6e76197-98ff-4b03-86c6-4e87ab928bb2	1	1	\N	Pearl	\N	\N	t	2025-11-11 07:13:58.617237	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "GREEN COTTAGE TRADING", "position": "SALES EXECUTIVE"}	2025-11-11 07:12:51.11109	2025-11-11 07:13:58.618111	\N	\N	pearl	\N
2034	88a69a26-5003-4659-88f5-300fceacd09d	1	1	\N	Arbayani	\N	\N	t	2025-11-11 07:14:04.451504	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "GREEN COTTAGE TRADING", "position": "MARKETING ASSOCIATE", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 07:13:36.896596	2025-11-11 07:14:04.452246	\N	\N	arbayani	\N
1558	017a7e29-cc72-4e95-99c1-83417446e1ed	1	1	\N	Mariyah Anatasya	mariyahanatasya23@gmail.com	601131690502	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "GREEN COTTAGE TRADING", "position": "ADMIN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 06:22:09.065727	2025-11-11 07:15:10.901956	mariyahanatasya23@gmail.com	601131690502	mariyah anatasya	\N
2036	5d235baf-9a3d-4695-872f-16cbd2da08eb	1	1	\N	Kevin	\N	\N	t	2025-11-11 07:19:41.443085	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MAKE A DIFFERENT REALITY SDN BHD", "position": "SALES PERSON"}	2025-11-11 07:19:16.569974	2025-11-11 07:19:41.443755	\N	\N	kevin	\N
1188	7f768fc5-65e4-407c-9332-3d485ab22c70	1	1	\N	Stephen Lim	stephenlim17888@gmail.com	601128251969	t	2025-11-07 10:27:42.373464	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MAKE A DIFFERENT REALITY SDN BHD", "position": "DIRECT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 10:27:24.477045	2025-11-11 07:20:15.487849	stephenlim17888@gmail.com	601128251969	stephen lim	\N
2037	ebb1592f-1692-4b17-8d06-5b7dd635b910	1	1	\N	Queenie	\N	\N	t	2025-11-11 07:25:16.748101	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MAKE A DIFFERENT REALITY SDN BHD", "position": "PIC"}	2025-11-11 07:24:55.991962	2025-11-11 07:25:16.748885	\N	\N	queenie	\N
2038	16524a4c-f8c7-4b46-9e99-8023650fce96	1	1	\N	Grace Tsen	\N	\N	t	2025-11-11 07:27:40.738205	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "APG REMISIER", "position": "MARKETING REPRESENTATIVE"}	2025-11-11 07:27:29.624427	2025-11-11 07:27:40.738969	\N	\N	grace tsen	\N
2040	e57a5ef7-6d55-433b-9ddd-b5b1244958a1	1	1	\N	Jacky Wong	\N	\N	t	2025-11-11 07:33:14.105855	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "MANULIFE MALAYSIA", "position": "SENIOR MANAGEMENT"}	2025-11-11 07:32:57.298793	2025-11-11 07:33:14.106721	\N	\N	jacky wong	\N
2041	5e49541e-5396-47f1-a94c-0f4c41889f55	1	1	\N	Jacob Chong	\N	\N	t	2025-11-11 07:34:52.819948	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "I LOVE MALAYSIA FRUITS SDN BHD", "position": "GENERAL MANAGER"}	2025-11-11 07:34:42.189135	2025-11-11 07:34:52.820817	\N	\N	jacob chong	\N
2043	24d34904-e043-4bc2-99d6-f0af6c3b7b3f	1	1	\N	Carol	\N	\N	t	2025-11-11 07:39:51.425326	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SUNBEAR", "position": "SALES & MARKETING"}	2025-11-11 07:39:42.988197	2025-11-11 07:39:51.426032	\N	\N	carol	\N
1978	4cb42aa4-0c9c-410e-8a17-d401034280c1	1	1	\N	Lorita	loritajendu21@gmail.com	60162720264	t	2025-11-11 07:43:53.861053	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SUNBEAR", "position": "SALES & MARKETING", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-09 07:54:15.677605	2025-11-11 07:43:53.861845	loritajendu21@gmail.com	60162720264	lorita	\N
80	69f1452a-dc56-41e4-88e2-aecc1e4647f8	1	1	\N	Hariharan Hemarajan	\N	012-3325977	t	2025-11-11 07:53:33.279926	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "OFFSHOREGIGS SDN BHD", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:36:13.527231	2025-11-11 07:53:33.280754	\N	0123325977	hariharan hemarajan	\N
2046	b0b8cbbc-5f3d-429e-9719-7875dc04cdc5	1	1	\N	Franky Wong	\N	\N	t	2025-11-11 07:58:10.269617	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KK COOL", "position": "STAFF"}	2025-11-11 07:58:02.719274	2025-11-11 07:58:10.270272	\N	\N	franky wong	\N
1245	c6db4c46-8a26-42ad-8089-18d4c000dc8a	1	1	\N	Roger Ting	Rogertim84@gmail.com	60168537173	t	2025-11-08 00:36:00.705519	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "WSG GROUP", "position": "GRAPHIC DESIGNER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 00:33:49.601841	2025-11-11 08:04:09.123532	rogertim84@gmail.com	60168537173	roger ting	\N
2049	97c45550-865a-46f8-b048-7af91da80b26	1	1	\N	Mark	\N	\N	t	2025-11-11 08:04:47.045292	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG GROUP", "position": "MARKETING"}	2025-11-11 08:04:34.664125	2025-11-11 08:04:47.046028	\N	\N	mark	\N
2050	66368d0e-c8b7-4b19-b75a-198de80e7638	1	1	\N	May Chan	\N	\N	t	2025-11-11 08:06:13.976918	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG GROUP", "position": "ACCOUNT EXECUTIVE"}	2025-11-11 08:06:02.640339	2025-11-11 08:06:13.97775	\N	\N	may chan	\N
1451	f7da3e0c-b21f-4bda-844c-33ba4157463a	1	1	\N	Aleyaa Huda	aleyaa76@gmail.com	60178337642	t	2025-11-08 03:50:24.073959	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "GREEN COTTAGE TRADING", "position": "ADMIN", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 03:50:24.073959	2025-11-11 07:14:27.02659	aleyaa76@gmail.com	60178337642	aleyaa huda	\N
781	b5c911c7-d27f-4945-90b8-92f5b159d2d0	1	1	\N	Kenny G.	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "Delegate", "company": "NAM HENG SAFETY GLASS (SABAH) SDN BHD", "position": "SALES EXEC", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:49:04.520882	2025-11-12 00:59:44.024614	\N	\N	kenny g.	\N
1146	5f4b20e3-b8cf-42ce-a39c-80486da8795c	1	3	\N	Joey Pang	\N	\N	t	2025-11-07 11:26:53.880817	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "MANULIFE MALAYSIA", "position": "WEALTH MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:47:09.676173	2025-11-11 07:33:29.639258	\N	\N	joey pang	\N
2042	c3c42611-0792-4227-be1b-de33742d4042	1	1	\N	Randhowen	\N	\N	t	2025-11-11 07:36:17.127145	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SEBANDO ENTREPRISE", "position": "CEO"}	2025-11-11 07:35:59.089763	2025-11-11 07:36:17.127935	\N	\N	randhowen	\N
2045	b5fb8821-9214-43b0-98bd-e2a2629e455d	1	1	\N	Maheswaran	\N	\N	t	2025-11-11 07:51:52.447396	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "OFFSHOREGIGS SDN BHD", "position": "CTO"}	2025-11-11 07:51:36.690027	2025-11-11 07:51:52.448366	\N	\N	maheswaran	\N
619	7d5abb29-ff2a-4841-b823-7d5eb8ab2a63	1	1	\N	Siti Aisyah Tohing	\N	60109436058	t	2025-11-11 07:57:01.195504	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "AL-WAAQIAH ACADEMY", "position": "FOUNDER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.450044	2025-11-11 07:57:01.196098	\N	60109436058	siti aisyah tohing	\N
2047	857c5f5b-fa7d-480f-9073-63a8ec30c2eb	1	1	\N	James Lee	\N	\N	t	2025-11-11 07:59:25.887317	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KK COOL", "position": "STAFF"}	2025-11-11 07:58:58.805329	2025-11-11 07:59:25.888187	\N	\N	james lee	\N
2048	194b56ed-8ef2-4899-b16c-3388d1559688	1	1	\N	Arizan Ariffin	\N	\N	t	2025-11-11 08:03:02.370631	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KK COOL", "position": "MANAGER"}	2025-11-11 08:02:04.373845	2025-11-11 08:03:02.372651	\N	\N	arizan ariffin	\N
2051	f64a9c3b-d7e7-402d-857c-15b6aac6ca0f	1	1	\N	Imam Ariff	\N	\N	t	2025-11-11 08:07:24.982428	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MAMI RASHID ENTREPRISE", "position": "STAFF"}	2025-11-11 08:06:56.632664	2025-11-11 08:07:24.98316	\N	\N	imam ariff	\N
2052	57191980-fb93-4031-b05b-41dfe32c0109	1	1	\N	Rahimah Binti Marasik	\N	\N	t	2025-11-11 08:09:25.695481	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "LEMBAGA KOKO", "position": "STAFF"}	2025-11-11 08:09:06.827269	2025-11-11 08:09:25.696556	\N	\N	rahimah binti marasik	\N
2054	382f635d-1b0c-4389-97b9-50aa805abfeb	1	1	\N	Lofina	\N	\N	t	2025-11-11 08:12:11.003403	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "INDUSTRIAL DEPARTMENT", "position": "DEVELOPMENT OFFICER"}	2025-11-11 08:11:59.550889	2025-11-11 08:12:11.004076	\N	\N	lofina	\N
2055	4cd4e33a-2559-4562-b6cc-4c185b7e58db	1	1	\N	Murniwati	\N	\N	t	2025-11-11 08:13:27.177181	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "EVERGOLD METAL ROOFING", "position": "SALES"}	2025-11-11 08:13:18.562462	2025-11-11 08:13:27.177874	\N	\N	murniwati	\N
2056	a931e1d0-3522-4272-bdc6-911ab8953bcb	1	1	\N	Rojita	\N	\N	t	2025-11-11 08:14:54.199757	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "EVERGOLD METAL ROOFING", "position": "SALES"}	2025-11-11 08:14:38.243016	2025-11-11 08:14:54.200336	\N	\N	rojita	\N
2057	8db25c27-3700-4915-a939-0e8712dc723c	1	1	\N	Mary Chiam	\N	\N	t	2025-11-11 08:16:37.869831	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "WSG GROUP", "position": "PA"}	2025-11-11 08:16:16.148764	2025-11-11 08:16:37.870435	\N	\N	mary chiam	\N
2063	591b3c44-eb6c-4f18-83d6-907e0cc87881	1	1	\N	Vanessa	\N	\N	t	2025-11-11 08:35:16.761167	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "COCOA KINGDOM", "position": "SA"}	2025-11-11 08:34:53.59731	2025-11-11 08:35:16.761867	\N	\N	vanessa	\N
1999	d130a994-741b-4568-baf6-e3df3c7328ce	1	1	\N	Marcella	marcella438@gmail.com	601125216953	t	2025-11-09 08:21:07.07917	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "EVERGOLD METAL ROOFING", "position": "SALES", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-09 08:21:07.07917	2025-11-11 08:13:42.349221	marcella438@gmail.com	601125216953	marcella	\N
2065	b25b6c2c-0f89-4f03-ae08-bfa8fd1d5d36	1	1	\N	Carl	\N	\N	t	2025-11-11 08:40:06.451734	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CELCOM DIGI BERHAD", "position": "ACCOUNT MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 08:38:32.961587	2025-11-11 08:40:06.452475	\N	\N	carl	\N
2066	549eacdc-e0a0-41fe-8eef-a2849b616260	1	1	\N	Alief	\N	\N	t	2025-11-11 08:47:09.464632	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CELCOM DIGI BERHAD", "position": "ACCOUNT MANAGER"}	2025-11-11 08:47:00.721718	2025-11-11 08:47:09.465335	\N	\N	alief	\N
2067	93389c00-7185-455b-b124-b9c5fea5e216	1	1	\N	Najib Shah	\N	\N	t	2025-11-11 08:51:23.428379	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "HUMANCE", "position": "COO"}	2025-11-11 08:48:41.178513	2025-11-11 08:51:23.429066	\N	\N	najib shah	\N
465	7c9d343f-d65e-4364-bd98-9d4c20393cd3	1	1	\N	Rashidah Binti Awang Jaafar	\N	60146501207	t	2025-11-11 08:08:07.147997	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MAMI RASHID ENTREPRISE", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.596879	2025-11-11 08:08:07.14871	\N	60146501207	rashidah binti awang jaafar	\N
2058	c5b86322-8ac4-40db-ba1f-41167313e1fc	1	1	\N	Dryl Dee	\N	\N	t	2025-11-11 08:19:09.874511	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "REVIEWBAH", "position": "SOFTWARE ENGINEER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 08:17:39.052079	2025-11-11 08:19:09.875259	\N	\N	dryl dee	\N
384	5cab2191-b4f2-4ea8-abc9-b5d9913ebdeb	1	1	\N	Bui Xin Lyn Sharlyn	\N	0168190983	t	2025-11-05 12:01:13.837894	25	1	1	\N	\N	\N	{"role": "VIP", "company": "COCOA KINGDOM", "position": "GENERAL MANAGER", "coupon_referral": "VIPSP", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-05 07:58:45.816158	2025-11-11 08:26:24.019594	\N	0168190983	bui xin lyn sharlyn	\N
2061	d06bfb24-0689-46a2-9a17-56441c460d6a	1	1	\N	Safra	\N	\N	t	2025-11-11 08:32:42.832549	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "COCOA KINGDOM", "position": "SA"}	2025-11-11 08:32:29.465483	2025-11-11 08:32:42.833255	\N	\N	safra	\N
2053	1150f214-a753-4e40-ad06-636337645449	1	1	\N	Julianah Binti Bakar	\N	\N	t	2025-11-11 08:10:42.635619	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "LEMBAGA KOKO", "position": "MANAGER"}	2025-11-11 08:10:33.600156	2025-11-11 08:10:42.637481	\N	\N	julianah binti bakar	\N
538	de4b645b-94c6-4b90-b653-d4e0042f3d73	1	9	\N	Alex Quek Seow Koon	\N	\N	f	\N	\N	0	1	\N	\N	\N	{"role": "VVIP", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 05:59:33.958082	2025-11-11 23:56:57.661727	\N	\N	alex quek seow koon	\N
156	ccfeb84f-c860-493d-beeb-3552e3901c9c	1	1	\N	Christopher Hilarion	\N	0168308697	t	2025-11-11 08:20:25.1521	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "MEGA CITY BUILDER SDN BHD", "position": "ASSISTANT SALES MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 07:10:35.774756	2025-11-11 08:20:25.152843	\N	0168308697	christopher hilarion	\N
2060	81e5ecaa-3810-4b97-bb41-7dfbdd1bd2a2	1	1	\N	Cira	\N	\N	t	2025-11-11 08:31:52.640907	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "COCOA KINGDOM", "position": "SA"}	2025-11-11 08:31:41.522046	2025-11-11 08:31:52.64166	\N	\N	cira	\N
2062	afe1c06c-951f-49b4-b6f1-70de638f88b2	1	1	\N	Vyshane	\N	\N	t	2025-11-11 08:33:44.774523	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "COCOA KINGDOM", "position": "MARKETING"}	2025-11-11 08:33:33.316077	2025-11-11 08:33:44.775214	\N	\N	vyshane	\N
2064	b96ae41a-bdd0-46aa-87b2-527caafcf8dc	1	1	\N	Amanie	\N	\N	t	2025-11-11 08:36:24.484466	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "COCOA KINGDOM", "position": "SA"}	2025-11-11 08:36:13.657193	2025-11-11 08:36:24.485196	\N	\N	amanie	\N
226	f10a32a9-f11c-47f5-a4c8-dc2d3e13e544	1	5	\N	Mohd Halfian Abdul Majid	\N	6013-559-0588	t	2025-11-05 08:08:48.381222	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "CELCOM DIGI BERHAD", "position": "HEAD OF SABAH REGION", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-03 10:38:42.381063	2025-11-11 08:42:14.283094	\N	60135590588	mohd halfian abdul majid	\N
43	66e45522-dc37-44e4-9b2b-53be0d9072e9	1	1	\N	Venice Wong	\N	016-8126562	t	2025-11-07 00:23:38.076057	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "REMAJAYA SDN BHD", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 07:12:51.029202	2025-11-11 08:43:19.132279	\N	0168126562	venice wong	\N
743	003ebdae-1360-402c-85df-b4913c068a12	1	1	\N	Nelson Yong	nelson_yvf@hotmail.com	60132080811	t	2025-11-07 00:19:42.335316	\N	1	1	\N	\N	\N	{"role": "Invited Delegate", "company": "REMAJAYA SDN BHD", "position": "PROJECT EXEC", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:14:59.855597	2025-11-11 08:43:38.912732	nelson_yvf@hotmail.com	60132080811	nelson yong	\N
904	280f28d9-d448-4d88-91ec-2f9f1921e656	1	1	\N	Walter	walter.gitok@gmail.com	60148614103	t	2025-11-07 04:17:27.595136	23	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "STAFF", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:17:09.671051	2025-11-11 23:57:08.22531	walter.gitok@gmail.com	60148614103	walter	\N
2068	a34dcaac-ee58-4722-ba4e-3fbfc93514ad	1	1	\N	Justin Chong	\N	\N	t	2025-11-11 08:55:32.174012	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "REVIEWBAH", "position": "CMO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 08:53:48.879909	2025-11-11 08:55:32.174904	\N	\N	justin chong	\N
615	bf2415b3-3165-44f6-92d3-7c05951a3264	1	2	\N	Ms Liya	\N	60146437566	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "DE'BAKEMATES", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 14:44:17.404632	2025-11-11 23:51:02.723654	\N	60146437566	ms liya	\N
2069	aa54ad71-23de-46e7-b84a-9d6913ceeb46	1	1	\N	Zuhairah	\N	\N	t	2025-11-11 23:51:27.623772	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "DE'BAKEMATES", "position": "DIRECTOR"}	2025-11-11 23:50:21.056133	2025-11-11 23:51:27.62508	\N	\N	zuhairah	\N
2070	48de57af-7082-48f1-a583-21cc31200789	1	1	\N	Johansson Voo	\N	\N	t	2025-11-11 23:52:39.63262	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "DML PRODUCTS (EAST MALAYSIA) SDN BHD", "position": "DIRECTOR", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 23:52:19.845989	2025-11-11 23:53:25.225757	\N	\N	johansson voo	\N
2071	f3586b48-ad4e-45de-bc56-7d05aede1fe5	1	1	\N	Welson Yong	\N	\N	t	2025-11-11 23:56:18.380077	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "MANAGER"}	2025-11-11 23:56:09.62367	2025-11-11 23:56:18.380695	\N	\N	welson yong	\N
634	04647f87-d6cf-4489-b510-ebf5fd528cdd	1	1	\N	Dayang Aini Binti Lasikan	ainifyg@gmail.com	60138994836	t	2025-11-06 23:53:24.803501	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BP ALUMINIUM EXTRUSION SDN BHD", "position": "DRAFTER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 23:43:13.506257	2025-11-11 23:57:26.411576	ainifyg@gmail.com	60138994836	dayang aini binti lasikan	\N
76	0c4461eb-3dff-4ddd-9252-d6393f670063	1	1	\N	Billy Lim	\N	012-8073203	f	\N	\N	0	1	\N	\N	\N	{"role": "Exhibitor", "company": "NHG GLASS INDUSTRIES (SABAH) SDN BHD", "position": "", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-10-31 08:33:55.644185	2025-11-11 23:59:54.381672	\N	0128073203	billy lim	\N
2072	a66701ae-eed1-4756-ac18-87b82694155e	1	1	\N	Gloria Chaw	\N	\N	t	2025-11-12 00:00:59.839809	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SME SABAH", "position": "EXECUTIVE SECRETARY"}	2025-11-12 00:00:44.443465	2025-11-12 00:00:59.840455	\N	\N	gloria chaw	\N
2073	1a40db72-16d9-4642-8f24-5adc9a45ef79	1	1	\N	Glibert Chan	\N	\N	t	2025-11-12 00:11:03.407293	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "ADSMART MARKETING", "position": "SALES EXECUTIVE"}	2025-11-12 00:10:35.9048	2025-11-12 00:11:03.408219	\N	\N	glibert chan	\N
2074	8692a323-5af8-477a-a1f7-24e13e3462ff	1	1	\N	Eugene Ng	\N	\N	t	2025-11-12 00:13:55.980167	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "PUMM", "position": "DEPUTY PRESIDENT"}	2025-11-12 00:13:43.486197	2025-11-12 00:13:55.980808	\N	\N	eugene ng	\N
2075	d206a4f3-631f-4745-8318-3c7729bbd002	1	1	\N	Muhammad Siddeq Bin Ibrahim	\N	\N	t	2025-11-12 00:15:39.01378	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "D-QAS KITCHEN", "position": "OWNER"}	2025-11-12 00:15:30.835818	2025-11-12 00:15:39.014474	\N	\N	muhammad siddeq bin ibrahim	\N
2076	6d0bcd1a-b01b-43d7-9417-e1e6968baa93	1	1	\N	Peng Hong Yi	\N	\N	t	2025-11-12 00:17:53.664827	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "PU-YIN  CONSTRUCTION", "position": "CEO"}	2025-11-12 00:17:26.162255	2025-11-12 00:17:53.665537	\N	\N	peng hong yi	\N
2077	566d1160-4eb5-4c6a-9ad5-144f09bd4c52	1	1	\N	Dr. Roger Lo	\N	\N	t	2025-11-12 00:27:01.313169	\N	1	1	\N	\N	\N	{"role": "Speaker", "company": "PU-YIN CONSTRUCTION", "position": "CHAIRMAN"}	2025-11-12 00:26:14.315869	2025-11-12 00:27:01.314068	\N	\N	dr. roger lo	\N
494	9902db74-25fd-4a5a-b872-1f5cafb1cf7d	1	1	\N	Amanda Chu	\N	60199333337	t	2025-11-07 00:03:43.967555	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KKIP SDN BHD", "position": "MANAGER - SALES & MAREKTING", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-06 02:23:46.803097	2025-11-12 00:31:32.652343	\N	60199333337	amanda chu	\N
2078	6734caa9-921f-4f0b-8ca1-0381bef68774	1	1	\N	Fredneee	\N	\N	t	2025-11-12 00:31:52.604564	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "KKIP SDN BHD", "position": "SALES"}	2025-11-12 00:29:30.869673	2025-11-12 00:31:52.605289	\N	\N	fredneee	\N
2079	f13f88df-367b-4220-b709-bec923502e85	1	1	\N	Crystee Lim	\N	\N	t	2025-11-12 00:32:54.610167	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "WD HUB", "position": "DIRECTOR"}	2025-11-12 00:32:38.354659	2025-11-12 00:32:54.610885	\N	\N	crystee lim	\N
2080	e10a284f-0ab7-4792-bf7e-e9a58de95ec7	1	1	\N	Rozilydia Datuk Hj Haafar	\N	\N	t	2025-11-12 00:36:07.544287	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CREDIT GUARANTEE CORP", "position": "ASSISTANT RELATIONSHIP MANAGER"}	2025-11-12 00:35:53.751484	2025-11-12 00:36:07.544956	\N	\N	rozilydia datuk hj haafar	\N
2024	aab31d28-be64-4f42-9169-2d438b58c280	1	1	\N	Winica Bongoh	\N	\N	t	2025-11-11 06:21:21.512294	\N	1	1	\N	\N	\N	{"role": "Exhibitor", "company": "SABAH CREDIT CORPORATION", "position": "STAFF", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-11 06:21:11.223459	2025-11-12 00:36:49.705993	\N	\N	winica bongoh	\N
2081	e11419a3-1d77-4a7a-baf5-95557e75dda4	1	1	\N	Clarie	\N	\N	t	2025-11-12 00:38:17.851275	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "CREDIT GUARANTEE CORP", "position": "ASSISTANT RELATIONSHIP MANAGER"}	2025-11-12 00:38:05.393283	2025-11-12 00:38:17.85202	\N	\N	clarie	\N
755	e18e02a0-ede4-4b54-9e93-61b3c1ba7f9d	1	1	\N	Mclaren W. Yusof	leisuredmost@gmail.com	601125292445	t	2025-11-07 00:18:01.064666	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORNEO PACIFIC HOLDINGS SDN BHD", "position": "IT SUPPORT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:18:01.064666	2025-11-12 01:24:38.267131	leisuredmost@gmail.com	601125292445	mclaren w. yusof	\N
701	a6510883-0e73-401e-b47b-afe751188ec3	1	1	\N	Samantha Sulit	samanthasulit@gmail.com	601113349252	t	2025-11-07 00:05:58.728866	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "Daily Express", "position": "Reporter", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:05:58.728866	2025-11-12 01:38:13.677715	samanthasulit@gmail.com	601113349252	samantha sulit	\N
705	99e95f2d-7d20-49cf-a86f-26e34639f7c1	1	1	\N	Tracelynn Peter Jupili	tracelynn@sabahtourism.com	60138373177	t	2025-11-07 00:09:03.450221	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "MARKETING MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:06:57.828097	2025-11-12 00:45:07.153869	tracelynn@sabahtourism.com	60138373177	tracelynn peter jupili	\N
295	9144b196-242f-4356-a7eb-e02f57ee0d37	1	1	\N	Humprey Ginibun	\N	\N	t	2025-11-05 10:08:10.497579	\N	1	1	\N	\N	\N	{"role": "VIP", "company": "SABAH TOURISM BOARD", "position": "DEPUTY CEO", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-04 07:26:03.375752	2025-11-12 00:52:05.311208	\N	\N	humprey ginibun	\N
688	68c26dd0-386a-4b20-bea6-b18410f5c086	1	1	\N	Elsie Maria Marcus Jopony	elsie@sabahtourism.com	60138024331	t	2025-11-07 00:08:22.309039	23	1	1	\N	\N	\N	{"role": "Delegate", "company": "SABAH TOURISM BOARD", "position": "ASST DIGITAL & COMMUNICATIONS MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:02:43.704394	2025-11-12 00:53:02.089628	elsie@sabahtourism.com	60138024331	elsie maria marcus jopony	\N
2082	adaa4ddf-fc02-4f68-9b34-3dddcf06a6e6	1	1	\N	Shim Hon Fui	\N	\N	t	2025-11-12 00:59:26.284184	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "NAM HENG SAFETY GLASS (SABAH) SDN BHD", "position": "FINANCE MANAGER"}	2025-11-12 00:59:17.250301	2025-11-12 00:59:26.284973	\N	\N	shim hon fui	\N
728	7bc631e7-7f99-40da-8a17-cdd63365d4c4	1	1	\N	Muhammad Adly Azmy	azmyadl15@gmail.com	601162861506	t	2025-11-07 10:05:06.754371	\N	1	1	\N	\N	\N	{"role": "Delegate", "company": "BORNEO ECO TOUR SDN BHD", "position": "SOFTWARE ENGINEER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:27.874592	2025-11-12 01:04:11.509101	azmyadl15@gmail.com	601162861506	muhammad adly azmy	\N
675	9ef2174d-980b-449a-a8c0-9bc2fab76b01	1	1	\N	Lim Fui Tze	csy_lim@hotmail.com	601172686078	t	2025-11-07 00:00:22.499326	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "ADC DRIVING INSTITUTE SDN BHD", "position": "TUTOR ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:00:22.499326	2025-11-07 00:03:14.106995	csy_lim@hotmail.com	601172686078	lim fui tze	\N
704	6e1b98b2-efb1-4e4c-873b-911dec2c1c4d	1	1	\N	Rachel Stanis Buandih	rachelstanisbuandih2@gmail.com	60198697232	t	2025-11-07 00:06:54.86395	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Lembaga Kebudayaan Negeri Sabah", "position": "Researcher", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:06:54.86395	2025-11-07 00:06:54.86395	rachelstanisbuandih2@gmail.com	60198697232	rachel stanis buandih	\N
789	db20cc77-61a1-41e2-9e75-bcc26999f924	1	1	\N	Hanaa Wong Abdullah	hanaa.abdullah3@gmail.com	60138861153	t	2025-11-07 02:26:21.337169	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Rema Synergy PLT", "position": "Founder", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:26:21.337169	2025-11-07 02:26:21.337169	hanaa.abdullah3@gmail.com	60138861153	hanaa wong abdullah	\N
719	c4c6edb2-8565-4925-863a-60f7e0a2b9c6	1	1	\N	Kevin Wong	wwjds0808@gmail.com	60146568116	t	2025-11-07 00:09:38.440844	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "WWJD SOLUTION ", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:09:38.440844	2025-11-07 00:09:38.440844	wwjds0808@gmail.com	60146568116	kevin wong	\N
814	f2b1b79c-9f87-4246-96e5-b3edbdbddb71	1	1	\N	Armah @ Faridah Bt Ahmad	armahfaridah67@gmail.com	60165829084	t	2025-11-07 02:50:14.331107	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ARFA CATERING & BAKING", "position": "MANAGER", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:50:14.331107	2025-11-07 02:50:14.331107	armahfaridah67@gmail.com	60165829084	armah @ faridah bt ahmad	\N
816	d024fcb4-92d4-4690-a978-c281b8d87955	1	1	\N	Raymond Chon	Raymond.xcell@gmail.com	60186651685	t	2025-11-07 02:51:59.510156	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Koperasi Jerami Sabah Berhad ", "position": "Chairman", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:51:59.510156	2025-11-07 02:51:59.510156	raymond.xcell@gmail.com	60186651685	raymond chon	\N
1185	cc7c2aa8-add7-4f28-b898-3cacac0749dd	1	1	\N	Richard Tan Siaw Wen	tansiaw_wen@yahoo.com	60168279056	t	2025-11-07 10:19:06.173862	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "ICSB", "position": "Officer"}	2025-11-07 10:19:06.173862	2025-11-07 10:19:37.167623	tansiaw_wen@yahoo.com	60168279056	richard tan siaw wen	\N
725	42a13c99-db17-4c68-b671-98829f3edc4f	1	1	\N	𝖡𝗂𝖻𝗂𝖺𝗇𝖺 𝖡𝗍𝖾 𝖡𝖾𝗇𝗃𝖺𝗆𝗂𝗇	vycby783@gmail.com	601131598378	t	2025-11-07 00:11:15.302899	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "𝖡𝖯 𝖠𝗅𝗎𝗆𝗂𝗇𝗂𝗎𝗆 𝖤𝗑𝗍𝗋𝗎𝗌𝗂𝗈𝗇 𝖲𝖽𝗇. 𝖡𝗁𝖽. ", "position": "𝖯𝗋𝗈𝖼𝗎𝖼𝗍𝗂𝗈𝗇 𝖢𝗅𝖾𝗋𝗄", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:15.302899	2025-11-07 00:11:15.302899	vycby783@gmail.com	601131598378	𝖡𝗂𝖻𝗂𝖺𝗇𝖺 𝖡𝗍𝖾 𝖡𝖾𝗇𝗃𝖺𝗆𝗂𝗇	\N
817	188e11d6-a877-41df-b74d-8985fe653cfc	1	1	\N	Vincent Lee Chi Kiong	vincentlee58@yahoo.com	8613926833413	t	2025-11-07 02:53:38.615029	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "koperasi pertanian sacha inchi sandakan berhad", "position": "pengurusi", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 02:53:38.615029	2025-11-07 02:53:38.615029	vincentlee58@yahoo.com	8613926833413	vincent lee chi kiong	\N
1191	1ab81b7f-ed75-4fbf-8fa1-33a8dd889d09	1	1	\N	Leon	Leon53406@gmail.com	601155887377	t	2025-11-07 10:45:46.35903	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Leon Enterprise", "position": "Manager"}	2025-11-07 10:45:46.35903	2025-11-07 10:45:46.35903	leon53406@gmail.com	601155887377	leon	\N
974	310017b3-a01d-4b38-922c-a0829d49825c	1	1	\N	Simon Chua Chin Soon	simon.chua@srikom.com.my	60109312293	t	2025-11-07 06:01:21.323194	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sri komputer sdn bhd ", "position": "supervisor ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:01:21.323194	2025-11-07 06:01:47.960076	simon.chua@srikom.com.my	60109312293	simon chua chin soon	\N
964	de1e88e4-ecdc-4591-81bb-15b1ce0930b0	1	1	\N	Leong	Vawssb@gmail.com	60107993874	t	2025-11-07 05:36:15.147172	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "K&L Automation", "position": "Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:36:15.147172	2025-11-07 05:37:19.877994	vawssb@gmail.com	60107993874	leong	\N
975	7288d19e-4846-4b74-91b0-ca9611513b28	1	1	\N	Sandra Jerry	amor.chinta@yahoo.com	60109535257	t	2025-11-07 06:03:27.865151	29	1	1	\N	\N	\N	{"role": "Visitor", "company": "Alam Damai Resources", "position": "Pengurus", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:03:27.865151	2025-11-07 06:04:20.603113	amor.chinta@yahoo.com	60109535257	sandra jerry	\N
976	28d0220a-bfaf-4c54-9f4e-9231e85017c0	1	1	\N	Beatric	wongzhia1450@gmail.com	60194995764	t	2025-11-07 06:04:19.592489	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Everich Ventures Sdn Bhd", "position": "Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:04:19.592489	2025-11-07 06:04:47.486254	wongzhia1450@gmail.com	60194995764	beatric	\N
1020	9c2311cf-32ab-4bb2-8549-04fb4e2496d2	1	1	\N	Vincent Lee	vleekk99@yahoo.com	60198006055	t	2025-11-07 06:52:06.603025	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Unity Technology", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:52:06.603025	2025-11-07 06:52:44.912838	vleekk99@yahoo.com	60198006055	vincent lee	\N
1021	ec518488-2a89-4a93-9bee-b09766b75b2b	1	1	\N	Ng Keng Guan	Stephen.nkg@gmail.com	601116727287	t	2025-11-07 06:52:16.780715	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Cryptoera", "position": "Advisor", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:52:16.780715	2025-11-07 06:52:56.860487	stephen.nkg@gmail.com	601116727287	ng keng guan	\N
1022	fb6919c9-969e-460b-849f-660d56c79a66	1	1	\N	Wong Vun On	vunonwong@gmail.com	60146567088	t	2025-11-07 06:52:35.200714	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "A", "position": "A", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:52:35.200714	2025-11-07 06:52:53.181237	vunonwong@gmail.com	60146567088	wong vun on	\N
1024	422b46e7-ef74-4da2-a228-5b932c1a4149	1	1	\N	Linah	fadilahdeyla26@gmail.com	60168483666	t	2025-11-07 06:54:01.825008	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "_", "position": "_", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:54:01.825008	2025-11-07 06:54:01.825008	fadilahdeyla26@gmail.com	60168483666	linah	\N
914	73712dfd-c7fe-44e4-a671-4706dc39d45e	1	1	\N	Noor Intan Basar	NoorIntan.Basar@sabah.gov.my	601131583853	t	2025-11-07 04:34:34.569065	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Jabatan Hal Ehwal Wanita Sabah", "position": "Penolong Pengarah", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 04:34:34.569065	2025-11-07 04:34:34.569065	noorintan.basar@sabah.gov.my	601131583853	noor intan basar	\N
1194	c06f6e42-842f-4eba-9a16-879df1ca567e	1	1	\N	Lance Liaw	Chock5655@gmail.com	60168878588	t	2025-11-07 11:00:41.906746	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "HAG STORE SDN BHD", "position": "Director"}	2025-11-07 11:00:41.906746	2025-11-07 11:00:41.906746	chock5655@gmail.com	60168878588	lance liaw	\N
1195	7995f018-2cfe-448c-ae6e-cf3b015b986c	1	1	\N	Bosco Wong	wjchyang168@hotmail.com	60135163913	t	2025-11-07 11:00:57.92631	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Kyro Managemebt Sdn Bhd", "position": "Director"}	2025-11-07 11:00:57.92631	2025-11-07 11:00:57.92631	wjchyang168@hotmail.com	60135163913	bosco wong	\N
968	cfdbc4ab-4542-48d7-988e-c0cc02ac3306	1	1	\N	Abby Liong	abbyliong@gmail.com	60168305170	t	2025-11-07 05:46:44.662362	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:46:44.662362	2025-11-07 05:46:44.662362	abbyliong@gmail.com	60168305170	abby liong	\N
970	34b1d445-9bca-4624-8c98-6c8d788a31c2	1	1	\N	Jonathan Vun	Kenken950222@gmail.com	60198894911	t	2025-11-07 05:49:11.905096	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Dekez", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:49:11.905096	2025-11-07 05:49:11.905096	kenken950222@gmail.com	60198894911	jonathan vun	\N
971	0961b6bb-0087-4520-8b5b-aac65eaf9c4d	1	1	\N	Ginne	Chiun_91@hotmail.com	60146687768	t	2025-11-07 05:50:27.123799	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "V balloon", "position": "Owner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 05:50:27.123799	2025-11-07 05:50:27.123799	chiun_91@hotmail.com	60146687768	ginne	\N
984	23a49903-4f6b-4d03-913a-a99860209c59	1	1	\N	Carmen Wong	carmenwwn@yahoo.com	60143149494	t	2025-11-07 06:14:36.494298	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nyek seng engineering snd bhd", "position": "Ceo", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:14:36.494298	2025-11-07 06:15:01.881025	carmenwwn@yahoo.com	60143149494	carmen wong	\N
985	c3055540-084e-4048-83dc-c6f98301118d	1	1	\N	Sinar Uni Resources	Artong9@hotmail.com	60168122277	t	2025-11-07 06:15:19.006425	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sinar uni resources ", "position": "G manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:15:19.006425	2025-11-07 06:15:19.006425	artong9@hotmail.com	60168122277	sinar uni resources	\N
987	fb25afd3-43c6-4b37-a9d8-4f8ff607f213	1	1	\N	Freddie	resource.sabah@gmail.com	60168493228	t	2025-11-07 06:17:03.859572	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Resource ", "position": "Founder", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:17:03.859572	2025-11-07 06:17:43.54698	resource.sabah@gmail.com	60168493228	freddie	\N
988	dc638611-10c6-4229-91f6-ff1985eb69ce	1	1	\N	Doreen Chin Li Fui	dragon_firedog@yahoo.com	60168065881	t	2025-11-07 06:18:26.450919	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Resource ", "position": "Interior Design ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:18:26.450919	2025-11-07 06:18:55.224655	dragon_firedog@yahoo.com	60168065881	doreen chin li fui	\N
995	11e33d9b-d34f-459b-a7c9-6e27aa2b5a56	1	1	\N	Juliee Rosley	julieerosley@gmail.com	60146589468	t	2025-11-07 06:20:28.273097	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "Moerosa Enterprise ", "position": "marketing asst", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:20:28.273097	2025-11-07 06:21:01.21274	julieerosley@gmail.com	60146589468	juliee rosley	\N
999	37893360-7ca3-48a4-8295-1f6fffb89b69	1	1	\N	Harves	Haroinfoteam@gmail.com	60148771298	t	2025-11-07 06:26:47.42685	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Haro", "position": "Tech & design lead", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:26:47.42685	2025-11-07 06:26:47.42685	haroinfoteam@gmail.com	60148771298	harves	\N
1012	debbdfe4-15ad-41df-9714-b02bff8d3345	1	1	\N	Adam Lim	Adam.lim0719@gmail.com	60138683510	t	2025-11-07 06:42:35.03253	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Aa", "position": "representative", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:42:35.03253	2025-11-07 06:42:35.03253	adam.lim0719@gmail.com	60138683510	adam lim	\N
1001	34952d14-dd96-4877-9d83-b991f176ca1b	1	1	\N	Hilmi	muhammadhilmiamir@yahoo.com	60145687290	t	2025-11-07 06:29:47.068554	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:29:47.068554	2025-11-07 06:29:47.068554	muhammadhilmiamir@yahoo.com	60145687290	hilmi	\N
1002	494d1e84-e8b4-4731-8574-a4ef8a19f639	1	1	\N	Kiong Chang Richard	Shadowtiki@yahoo.com	60162627338	t	2025-11-07 06:29:54.134286	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SEAH", "position": "Supervisor ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:29:54.134286	2025-11-07 06:29:54.134286	shadowtiki@yahoo.com	60162627338	kiong chang richard	\N
1025	70eec245-55e0-4870-a339-69e486852ef8	1	1	\N	Asnah Guriaman	iamnatashanabila@gmail.com	60138578879	t	2025-11-07 06:54:27.813278	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "_", "position": "_", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:54:27.813278	2025-11-07 06:54:27.813278	iamnatashanabila@gmail.com	60138578879	asnah guriaman	\N
1026	0c5e8d6f-525d-42fa-aefe-483fb6e49b3e	1	1	\N	Fadilah	fadilahdeyla26@gmail.com	60168451734	t	2025-11-07 06:54:29.440686	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:54:29.440686	2025-11-07 06:54:29.440686	fadilahdeyla26@gmail.com	60168451734	fadilah	\N
1028	ae705b0a-a1e9-432a-8350-2eac6639792e	1	1	\N	Anly Tay	Anlytel8@yahoo.com	60138683316	t	2025-11-07 06:56:03.713077	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:56:03.713077	2025-11-07 06:56:03.713077	anlytel8@yahoo.com	60138683316	anly tay	\N
1029	ce5317b8-f7f1-4405-8cbb-5e519f37a58e	1	1	\N	Anwar Shah	Anwar.shah878@gmail.com	60138399778	t	2025-11-07 07:03:14.527574	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "QSB", "position": "Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:14.527574	2025-11-07 07:03:14.527574	anwar.shah878@gmail.com	60138399778	anwar shah	\N
1030	6581c947-cf03-4f25-977c-c68907546fac	1	1	\N	Akmal	akmalteting@gmail.com	601136248961	t	2025-11-07 07:03:15.645507	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "AT holidays Rental & Tours", "position": "Manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:15.645507	2025-11-07 07:03:15.645507	akmalteting@gmail.com	601136248961	akmal	\N
1031	3c76addb-2561-4823-a2d5-c9d4ea191c20	1	1	\N	Anna	annaraymond.sj@gmail.com	60194248247	t	2025-11-07 07:03:42.208064	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "IRBM", "position": "Executive", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:42.208064	2025-11-07 07:03:42.208064	annaraymond.sj@gmail.com	60194248247	anna	\N
1032	1f4c5424-3424-4fe1-bdc8-38f74cced467	1	1	\N	Rommie Kandau	rommie5544@gamil.com	601116055518	t	2025-11-07 07:03:45.178674	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Top spot supplies ", "position": "Business partner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:45.178674	2025-11-07 07:03:45.178674	rommie5544@gamil.com	601116055518	rommie kandau	\N
1033	eb6a8c9f-5476-42db-baf1-4fce19f7bc36	1	1	\N	Elizabeth Rais	elizabethelisce@gmail.com	60105909853	t	2025-11-07 07:03:46.546677	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Top Spot Supplies", "position": "Business Owner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:46.546677	2025-11-07 07:03:46.546677	elizabethelisce@gmail.com	60105909853	elizabeth rais	\N
1034	6b9b9764-78d0-4f5a-b0ce-f6d43297489c	1	1	\N	Ann	fuchsia891@gmail.com	60109302351	t	2025-11-07 07:03:46.852053	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ATHolidays", "position": "Staff", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:46.852053	2025-11-07 07:03:46.852053	fuchsia891@gmail.com	60109302351	ann	\N
1035	beb2e1e1-4d60-42da-8f88-c01093982343	1	1	\N	Linda	Lintuk_1107@yahoo.com	60198141800	t	2025-11-07 07:03:54.237642	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Aia Berhad", "position": "Agent", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:03:54.237642	2025-11-07 07:03:54.237642	lintuk_1107@yahoo.com	60198141800	linda	\N
1196	3ddcf4a1-3b9b-492d-b81f-2e4df7d5c0bd	1	1	\N	Datuk Dr Mohan	drmohangopalnaidoo@gmail.com	60198337401	t	2025-11-07 11:08:26.577901	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MOVIN TRAINING and RESOURCES ", "position": "CEO "}	2025-11-07 11:08:26.577901	2025-11-07 11:08:26.577901	drmohangopalnaidoo@gmail.com	60198337401	datuk dr mohan	\N
1201	6afb7352-f7ae-4059-b76c-37e922899484	1	1	\N	Colvin Teo Khang Wei	colvinteo@gmail.com	60168049748	t	2025-11-07 11:45:51.760699	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Grab", "position": "Driver"}	2025-11-07 11:45:51.760699	2025-11-07 11:45:51.760699	colvinteo@gmail.com	60168049748	colvin teo khang wei	\N
1039	a8d5211c-1695-4a84-8d5e-31c634a24903	1	1	\N	Willy Ching	Willyching189@gmail.com	60183839966	t	2025-11-07 07:08:09.286223	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Kone Elevator SB", "position": "Key Account Manager ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:08:09.286223	2025-11-07 07:08:09.286223	willyching189@gmail.com	60183839966	willy ching	\N
1040	d6c25900-4403-46d0-bb62-3a9ee04a57f6	1	1	\N	Lee Hwee Tatt	Hweetatt@gmail.com	60173418070	t	2025-11-07 07:08:45.478329	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Lee", "position": "Engineer", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:08:45.478329	2025-11-07 07:08:45.478329	hweetatt@gmail.com	60173418070	lee hwee tatt	\N
1056	dade3e01-b08f-4077-af5a-87401c180f19	1	1	\N	Rucben	Rkinspirations@gmail.com	60138818978	t	2025-11-07 07:59:03.501989	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "RKI CONSULTANCY SDN BHD", "position": "Director", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:59:03.501989	2025-11-07 07:59:03.501989	rkinspirations@gmail.com	60138818978	rucben	\N
1057	715f6542-1cb2-4c7e-955f-ecd7802ee179	1	1	\N	Christy Liew	christylvl@yahoo.com	60198324729	t	2025-11-07 07:59:51.038513	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "IQI ", "position": "Team Leader ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 07:59:51.038513	2025-11-07 07:59:51.038513	christylvl@yahoo.com	60198324729	christy liew	\N
1065	e8faacd7-27fe-45f9-b88d-df803a8fd380	1	1	\N	Yee Yong Jai	jobjiwaja@gmail.com	60169422111	t	2025-11-07 08:38:15.936799	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "B", "position": "B", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:38:15.936799	2025-11-07 08:38:33.774986	jobjiwaja@gmail.com	60169422111	yee yong jai	\N
703	c4ea2eb8-f458-4ae2-9dd5-9cf5b2eda840	1	1	\N	Melvin Jr Stephen John	nyst.wysrt@gmail.com	60102842343	t	2025-11-07 00:06:30.797015	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Seamex Association", "position": "Research Assistant", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:06:30.797015	2025-11-07 00:06:30.797015	nyst.wysrt@gmail.com	60102842343	melvin jr stephen john	\N
706	12b9b036-0316-4c2d-8f68-4bc11fbe1783	1	1	\N	Beautifully John	Beautifullyjohn1@gmail.com	60142814824	t	2025-11-07 00:07:12.476543	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ministry of tourism, culture and environmet", "position": "Secretary", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:07:12.476543	2025-11-07 00:07:12.476543	beautifullyjohn1@gmail.com	60142814824	beautifully john	\N
713	d19726b9-e3ad-4892-a082-6761c6a21f96	1	1	\N	Arysha Fatin Fifieyana Binti Andres	aryshafatinfifieyana@gmail.com	60128342494	t	2025-11-07 00:08:17.306483	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "KEPKAS ", "position": "FELO SMJ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:08:17.306483	2025-11-07 00:08:17.306483	aryshafatinfifieyana@gmail.com	60128342494	arysha fatin fifieyana binti andres	\N
730	245bae4a-a769-4892-8693-633f064a7d70	1	1	\N	Maymall Frayneey Kipli	Maydaykipli@gmail.com	60194134674	t	2025-11-07 00:11:53.276188	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Lembaga kebudayaan negeri sabah ", "position": "KERANI", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:11:53.276188	2025-11-07 00:11:53.276188	maydaykipli@gmail.com	60194134674	maymall frayneey kipli	\N
760	a02cb5c4-5777-44ed-89c8-c90c7129ef5b	1	1	\N	Jason Tai	jasontai@uniang.com	60178028088	t	2025-11-07 00:19:18.758275	23	1	1	\N	\N	\N	{"role": "Visitor", "company": "UNIANG PLASTIC INDUSTRIES SDN BHD", "position": "sales manager", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 00:19:18.758275	2025-11-07 00:20:23.819074	jasontai@uniang.com	60178028088	jason tai	\N
986	b2e50b4a-784f-47e3-9c56-b81d07a9af70	1	1	\N	Immuni Binti Lasahe	lasaheimmuni@gmail.com	60128022352	t	2025-11-07 06:16:55.174916	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Rhieyna Kitchen", "position": "Owner", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:16:55.174916	2025-11-07 06:16:55.174916	lasaheimmuni@gmail.com	60128022352	immuni binti lasahe	\N
1014	401f13d9-df50-4639-8ba6-5321a76f9b11	1	1	\N	Joecy Liau	joecyliau@gmail.com	60165723232	t	2025-11-07 06:48:14.404976	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "EL-TECH ENTERPRISE ", "position": "Admin", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:48:14.404976	2025-11-07 06:48:35.984403	joecyliau@gmail.com	60165723232	joecy liau	\N
1019	0e003814-5037-4173-a272-8231dbf5d700	1	1	\N	Mohd Faliq	faliq@sirim.my	60193142098	t	2025-11-07 06:51:53.845545	26	1	1	\N	\N	\N	{"role": "Visitor", "company": "SIRIM", "position": "Sr Key Account ", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 06:51:53.845545	2025-11-07 06:52:38.475165	faliq@sirim.my	60193142098	mohd faliq	\N
1058	c5a36263-893c-436c-b14d-a324e23fe116	1	1	\N	Yuki	yukisan228@gmail.com	60168338546	t	2025-11-07 08:06:27.705081	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-07 08:06:27.705081	2025-11-07 08:06:27.705081	yukisan228@gmail.com	60168338546	yuki	\N
1252	e4b2d409-6170-4f84-acf2-b01412ded7ee	1	1	\N	Lai Yick Hiung	yhlaikk@gmail.com	60168474409	t	2025-11-08 00:36:15.052006	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Digital Heritage Sdn Bhd", "position": "Software Engineer "}	2025-11-08 00:36:15.052006	2025-11-08 00:36:15.052006	yhlaikk@gmail.com	60168474409	lai yick hiung	\N
1254	6ea5d992-7ffc-421d-aaa4-0c63390c7901	1	1	\N	Shela Wang	shelawang014@gmail.com	60109493393	t	2025-11-08 00:37:24.488993	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Hainan association ", "position": "Youth leader"}	2025-11-08 00:37:24.488993	2025-11-08 00:37:24.488993	shelawang014@gmail.com	60109493393	shela wang	\N
1271	de41dd9c-8abc-428a-a3c2-a41c647dfa2c	1	1	\N	Jennifer Lo Pei Pei	Jenniferlo0701@gmail.com	60167183738	t	2025-11-08 00:48:01.983442	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Grace chapel penampang ", "position": "Co-worker"}	2025-11-08 00:48:01.983442	2025-11-08 00:50:14.126773	jenniferlo0701@gmail.com	60167183738	jennifer lo pei pei	\N
1277	01a47596-c206-4728-ad55-def9b947a6bd	1	1	\N	Kiung Jeon Shii	Davidkiung@hotmail.com	60168866900	t	2025-11-08 00:51:54.091597	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "3K cleaning and removation enterprise", "position": "Engineer"}	2025-11-08 00:51:54.091597	2025-11-08 00:51:54.091597	davidkiung@hotmail.com	60168866900	kiung jeon shii	\N
1278	d35a5839-0688-4937-a5f8-85b8208b74a6	1	1	\N	Ham Cheng Siong	alex_chengsiong@hotmail.com	60168009198	t	2025-11-08 00:52:10.428117	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Pac sdn bhd", "position": "Manager"}	2025-11-08 00:52:10.428117	2025-11-08 00:52:10.428117	alex_chengsiong@hotmail.com	60168009198	ham cheng siong	\N
1312	0e7f3b51-6aca-449d-860e-d2235e5cb8a0	1	1	\N	Joseph Wong	ph07_j@yahoo.com.sg	60168276218	t	2025-11-08 01:08:20.803002	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nil", "position": "Nil"}	2025-11-08 01:08:20.803002	2025-11-08 01:08:49.535338	ph07_j@yahoo.com.sg	60168276218	joseph wong	\N
1340	2895f15f-764c-4e9d-9d33-737d57d9aea7	1	1	\N	Ts Dr Sally Chen Sieng Yin	sally3028@gmail.com	60168322762	t	2025-11-08 01:28:27.201829	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "The Best Solution Management Sdn Bhd", "position": "Managing Director"}	2025-11-08 01:28:27.201829	2025-11-08 01:28:27.201829	sally3028@gmail.com	60168322762	ts dr sally chen sieng yin	\N
1352	baa5f36c-4cef-4359-8c6d-be73c5a3b99b	1	1	\N	Wally Chuan	lisher@hlib.hongleong.com.my	60168013899	t	2025-11-08 02:00:59.182131	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "EXC Wire & Cable", "position": "Regional Director"}	2025-11-08 02:00:59.182131	2025-11-08 02:01:17.461442	lisher@hlib.hongleong.com.my	60168013899	wally chuan	\N
1357	358f6519-076d-4fb2-b791-2c5a612a7819	1	1	\N	Mak Kin Yoong	kinyoongmak@gmail.com	60199733268	t	2025-11-08 02:27:34.509089	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Bornion Realty", "position": "Agent"}	2025-11-08 02:27:34.509089	2025-11-08 02:27:34.509089	kinyoongmak@gmail.com	60199733268	mak kin yoong	\N
1358	926c4d4e-744f-4458-a076-a3af96aa2b37	1	1	\N	Fong Vui Lan	vuilanfong@yahoo.com.sg	60198631833	t	2025-11-08 02:28:54.67525	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nil", "position": "Nil"}	2025-11-08 02:28:54.67525	2025-11-08 02:28:54.67525	vuilanfong@yahoo.com.sg	60198631833	fong vui lan	\N
1360	308cc934-58ff-4714-8f2a-b5957d70958d	1	1	\N	Synthia	synthialsg@yahoo.com.tw	60146785572	t	2025-11-08 02:29:25.287118	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nil", "position": "Nil"}	2025-11-08 02:29:25.287118	2025-11-08 02:29:25.287118	synthialsg@yahoo.com.tw	60146785572	synthia	\N
1361	38a526e4-c995-41ca-93d2-2aa104e4b715	1	1	\N	Wei Chui Yun	chuiyunwei@yahoo.com	60168308593	t	2025-11-08 02:29:42.952493	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Visitor", "position": "Visitor"}	2025-11-08 02:29:42.952493	2025-11-08 02:29:42.952493	chuiyunwei@yahoo.com	60168308593	wei chui yun	\N
1362	a8c20511-484e-4d07-9866-071d9344d068	1	1	\N	Chuah Lai Weng	chuahlw9@gmail.com	60124152180	t	2025-11-08 02:30:36.464819	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "PUBLIC BANK ", "position": "BANK OFFICER"}	2025-11-08 02:30:36.464819	2025-11-08 02:30:36.464819	chuahlw9@gmail.com	60124152180	chuah lai weng	\N
1363	c9e893cc-8088-4d18-aad4-e5ead3a5cf54	1	1	\N	Chong T.s	chongt01@yahoo.com	60198507498	t	2025-11-08 02:32:53.316827	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 02:32:53.316827	2025-11-08 02:32:53.316827	chongt01@yahoo.com	60198507498	chong t.s	\N
1369	f2076c02-e543-4a9a-938a-78ca1e4b63a6	1	1	\N	Inayan Nudding	inayandessert@gmail.com	60198077070	t	2025-11-08 02:34:33.851945	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nayan enterprise", "position": "Manager"}	2025-11-08 02:34:33.851945	2025-11-08 02:34:33.851945	inayandessert@gmail.com	60198077070	inayan nudding	\N
1370	8db051f9-330c-4032-bc07-4be5a2c80481	1	1	\N	Daniella Daring	daneladaring@gmail.com	60163218542	t	2025-11-08 02:34:50.805865	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "N.S. Lim & Co.", "position": "Partner"}	2025-11-08 02:34:50.805865	2025-11-08 02:34:50.805865	daneladaring@gmail.com	60163218542	daniella daring	\N
1371	65f79d67-a102-43f1-a785-749568d86088	1	1	\N	Iman Izzah	imanizzah19@gmail.com	601129940412	t	2025-11-08 02:35:57.595622	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 02:35:57.595622	2025-11-08 02:35:57.595622	imanizzah19@gmail.com	601129940412	iman izzah	\N
1372	157cb43a-a300-487d-b262-e8e294d9b188	1	1	\N	Jessie Chin	Jesschinnk@gmail.com	60128021095	t	2025-11-08 02:40:59.130308	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MK ENTERPRISE", "position": "Director"}	2025-11-08 02:40:59.130308	2025-11-08 02:40:59.130308	jesschinnk@gmail.com	60128021095	jessie chin	\N
1373	6325bbdd-83e9-4ef8-a8b9-0afa671fa910	1	1	\N	Ivan	ivan.lai@c.com	60168290833	t	2025-11-08 02:41:03.397159	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "KKM", "position": "kkm"}	2025-11-08 02:41:03.397159	2025-11-08 02:41:03.397159	ivan.lai@c.com	60168290833	ivan	\N
1374	1a6fbb94-b9c0-4847-bb6e-46229ac9ed71	1	1	\N	May Yapp	mayyappruivun@gmail.com	601172550228	t	2025-11-08 02:41:36.662963	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 02:41:36.662963	2025-11-08 02:41:36.662963	mayyappruivun@gmail.com	601172550228	may yapp	\N
1376	d26552bd-8288-42b3-a9f9-40a5dc4faa27	1	1	\N	Rusly	ruslymasalin@gmail.com	60128018109	t	2025-11-08 02:44:00.692752	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "D'Valley Park", "position": "Manager"}	2025-11-08 02:44:00.692752	2025-11-08 02:44:00.692752	ruslymasalin@gmail.com	60128018109	rusly	\N
1377	57d7908e-44be-415d-abfb-08317b28ede5	1	1	\N	Muhammad Iman Zul Hakim Bin Zoolhilmi	iman050106@gmail.com	601137430748	t	2025-11-08 02:44:57.703771	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Omniraise ", "position": "Sales Management"}	2025-11-08 02:44:57.703771	2025-11-08 02:44:57.703771	iman050106@gmail.com	601137430748	muhammad iman zul hakim bin zoolhilmi	\N
1378	2aa2a3f2-6f92-4e35-a17e-068a6ab6c284	1	1	\N	Wong	fcwong@hotmail.com	60178929699	t	2025-11-08 02:46:12.181967	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "FCF ", "position": "Director "}	2025-11-08 02:46:12.181967	2025-11-08 02:46:12.181967	fcwong@hotmail.com	60178929699	wong	\N
1379	2db34654-1856-492b-9fa8-39264002ea09	1	1	\N	Cy	Corp8118@gmail.com	60168303812	t	2025-11-08 02:47:05.734746	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "JKm", "position": "Deputy sec"}	2025-11-08 02:47:05.734746	2025-11-08 02:47:05.734746	corp8118@gmail.com	60168303812	cy	\N
1380	d93de6f6-8f43-4b13-8f26-2a0a5b0ee81c	1	1	\N	Eyen Khoo	Eyenkhoo1407@gmail.com	60198996033	t	2025-11-08 02:47:22.669701	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah Forestry Department", "position": "Researcher"}	2025-11-08 02:47:22.669701	2025-11-08 02:47:22.669701	eyenkhoo1407@gmail.com	60198996033	eyen khoo	\N
1381	f37dbcb4-1704-4caf-b3c1-40203d4e7e25	1	1	\N	Fam Yen Tze	yenzifam@yahoo.com	60168102478	t	2025-11-08 02:47:53.86031	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Season Master", "position": "clerk"}	2025-11-08 02:47:53.86031	2025-11-08 02:47:53.86031	yenzifam@yahoo.com	60168102478	fam yen tze	\N
1382	d306cce6-16d5-46ac-93b4-aa3d49612187	1	1	\N	Jeremy Stephen	jeremystephen.js@gmail.com	60177539897	t	2025-11-08 02:48:02.749889	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 02:48:02.749889	2025-11-08 02:48:02.749889	jeremystephen.js@gmail.com	60177539897	jeremy stephen	\N
1383	306da247-dbf4-41ca-82f6-df8e03dcc25b	1	1	\N	Dyi Ka Wai Jerry	badboy99308@yahoo.com	60168489120	t	2025-11-08 02:48:06.50646	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nippon paint sabah", "position": "Warehouse executive "}	2025-11-08 02:48:06.50646	2025-11-08 02:48:06.50646	badboy99308@yahoo.com	60168489120	dyi ka wai jerry	\N
1384	d686be99-adb0-46d3-af8c-0dc2f45dfb7f	1	1	\N	Rachel Wong	wsyit76@gmail.com	60168130730	t	2025-11-08 02:48:19.48078	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Nestle Products Sdn Bhd", "position": "DSE"}	2025-11-08 02:48:19.48078	2025-11-08 02:48:19.48078	wsyit76@gmail.com	60168130730	rachel wong	\N
1385	95e43781-733b-467d-9b75-0245d59f70fb	1	1	\N	Abd Nohan Bin Salin	rayhanalia@gmail.com	60128426598	t	2025-11-08 02:48:22.233549	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 02:48:22.233549	2025-11-08 02:48:22.233549	rayhanalia@gmail.com	60128426598	abd nohan bin salin	\N
1386	08f7b67b-2b13-4bf8-b41f-9a7fe25d324e	1	1	\N	Ismail Bin Sennang	ismailsennang1954@gmail.com	60125811162	t	2025-11-08 02:49:06.716881	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "S", "position": "Pelawat"}	2025-11-08 02:49:06.716881	2025-11-08 02:49:06.716881	ismailsennang1954@gmail.com	60125811162	ismail bin sennang	\N
1387	f32b03ef-bb9a-4216-94c5-98d89ae95242	1	1	\N	Muizzuddin	MuizzuddinMoni@gmail.com	60168119311	t	2025-11-08 02:50:36.232972	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ascend Digital", "position": "Co-Founder"}	2025-11-08 02:50:36.232972	2025-11-08 02:50:36.232972	muizzuddinmoni@gmail.com	60168119311	muizzuddin	\N
1388	7b0658b4-606d-4d03-9cb0-126eca868faf	1	1	\N	Jackson	jacksonchang87@gmail.com	60109312083	t	2025-11-08 02:50:58.455069	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 02:50:58.455069	2025-11-08 02:50:58.455069	jacksonchang87@gmail.com	60109312083	jackson	\N
1389	5cd400e6-2f02-4e04-b72e-f9f4611db5dd	1	1	\N	Zaeem Zharfan	zaeemzharfan@gmail.com	60109332297	t	2025-11-08 02:51:57.863839	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ascend", "position": "Company"}	2025-11-08 02:51:57.863839	2025-11-08 02:51:57.863839	zaeemzharfan@gmail.com	60109332297	zaeem zharfan	\N
1390	0598c878-966f-4e9d-a809-b801b09683bd	1	1	\N	Shereen Yeo	Shereen.yeop@gmail.com	60166662187	t	2025-11-08 02:56:04.531016	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mme", "position": "Admin"}	2025-11-08 02:56:04.531016	2025-11-08 02:56:04.531016	shereen.yeop@gmail.com	60166662187	shereen yeo	\N
1391	67f8860e-a3f5-4889-a9d0-81b765358fb7	1	1	\N	Atijah Parmin	Atijahparmin67@gmail.com	60128516065	t	2025-11-08 02:56:53.331158	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 02:56:53.331158	2025-11-08 02:56:53.331158	atijahparmin67@gmail.com	60128516065	atijah parmin	\N
1392	18bf23b1-adb2-41b2-8723-5790abc90297	1	1	\N	Iylia Dominic	aiylia91@gmail.com	60108088130	t	2025-11-08 02:56:56.5762	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 02:56:56.5762	2025-11-08 02:56:56.5762	aiylia91@gmail.com	60108088130	iylia dominic	\N
1398	038cc36b-78dd-4542-a6c3-2efd679dac11	1	1	\N	Edward Ha	siauyew@gmail.com	60168137889	t	2025-11-08 03:01:42.915043	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Visitor", "position": "Visitor "}	2025-11-08 03:01:42.915043	2025-11-08 03:01:42.915043	siauyew@gmail.com	60168137889	edward ha	\N
1399	68c66240-ccfe-4252-b932-38558a7d627b	1	1	\N	Shirley	snowie336@gmail.com	60109530788	t	2025-11-08 03:02:11.127194	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Visitor ", "position": "Visitor "}	2025-11-08 03:02:11.127194	2025-11-08 03:02:11.127194	snowie336@gmail.com	60109530788	shirley	\N
1400	b2553e4c-a70a-4654-9a29-28df2d84e8c0	1	1	\N	Miki	doreensynyee@hotmail.com	60168487063	t	2025-11-08 03:04:30.116608	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "—", "position": "pen ga ra h"}	2025-11-08 03:04:30.116608	2025-11-08 03:04:30.116608	doreensynyee@hotmail.com	60168487063	miki	\N
1402	fdfe44d7-26eb-48ee-9701-737be0027b15	1	1	\N	Wuang Ching	Wuangching323@gmail.com	60128295322	t	2025-11-08 03:06:42.850949	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Graceworth", "position": "Manager"}	2025-11-08 03:06:42.850949	2025-11-08 03:06:42.850949	wuangching323@gmail.com	60128295322	wuang ching	\N
1403	44ca4f26-1b9e-4aed-8b49-ae878044f548	1	1	\N	Erlina Binti Hamdan	terabusa@gmail.com	60122716665	t	2025-11-08 03:06:59.180077	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:06:59.180077	2025-11-08 03:06:59.180077	terabusa@gmail.com	60122716665	erlina binti hamdan	\N
1412	4e58887b-2b63-485b-850b-f2fdf800dcb0	1	1	\N	Hiew Kim Fatt	kfhiew@yahoo.com	60128131611	t	2025-11-08 03:11:32.302157	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SCHB Engineering ", "position": "Manager"}	2025-11-08 03:11:32.302157	2025-11-08 03:11:32.302157	kfhiew@yahoo.com	60128131611	hiew kim fatt	\N
1413	765e5053-d0a0-462d-a944-eaf7c7ff20e5	1	1	\N	David	Davidlvseng@gmail.com	60168302372	t	2025-11-08 03:11:39.41455	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ayamesra Sdn Bhd", "position": "Marketing Manager"}	2025-11-08 03:11:39.41455	2025-11-08 03:11:39.41455	davidlvseng@gmail.com	60168302372	david	\N
1414	f520e787-9c61-452a-9649-971f47ce6446	1	1	\N	Mandy	Loyiyi326@gmail.com	60169177935	t	2025-11-08 03:11:50.052447	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Strategic security ", "position": "Co sec "}	2025-11-08 03:11:50.052447	2025-11-08 03:11:50.052447	loyiyi326@gmail.com	60169177935	mandy	\N
1415	238522ee-a3c2-420b-a207-9e0b8ae61eeb	1	1	\N	Jack	chan.yeejack1999@gmail.com	601138082308	t	2025-11-08 03:13:04.419985	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:13:04.419985	2025-11-08 03:13:04.419985	chan.yeejack1999@gmail.com	601138082308	jack	\N
1416	6b470757-9c2e-4360-877c-7e61db951319	1	1	\N	Liau Siow Yen	liausy2022@gmail.com	60138839101	t	2025-11-08 03:13:47.33305	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:13:47.33305	2025-11-08 03:13:47.33305	liausy2022@gmail.com	60138839101	liau siow yen	\N
1417	48a94945-e55f-40e3-aa08-8f7947ec78e8	1	1	\N	Amelia	amelia.inbam@gmail.com	60198022946	t	2025-11-08 03:14:02.409937	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Jesselton medicak centre ", "position": "Senior speech therapist "}	2025-11-08 03:14:02.409937	2025-11-08 03:14:02.409937	amelia.inbam@gmail.com	60198022946	amelia	\N
1418	dc43b91b-eb9b-4e82-8890-dd008810df5c	1	1	\N	Serenus Kimpun	serenuseyon@gmail.com	601155054201	t	2025-11-08 03:15:08.245685	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 03:15:08.245685	2025-11-08 03:15:08.245685	serenuseyon@gmail.com	601155054201	serenus kimpun	\N
1419	b82a77e4-a0a0-4f90-ae7b-55d97433ed43	1	1	\N	Mohd Affy Junairey	mohdaffy.j@gmail.com	601162552305	t	2025-11-08 03:15:36.443944	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "My Broadband Centre SDN BHD", "position": "Sales Person"}	2025-11-08 03:15:36.443944	2025-11-08 03:15:36.443944	mohdaffy.j@gmail.com	601162552305	mohd affy junairey	\N
1420	713da915-bb5d-4cf5-9846-ce456e613d2e	1	1	\N	Traccy	chinyinchun@yahoo.com	60198125665	t	2025-11-08 03:15:38.930304	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "CKM TRADING COMPANY ", "position": "Sales Manager "}	2025-11-08 03:15:38.930304	2025-11-08 03:15:38.930304	chinyinchun@yahoo.com	60198125665	traccy	\N
1421	e9f7f7c3-425c-4523-b557-18dafe7c611a	1	1	\N	Kacylina Jakol	Kacylyna@gmail.com	60168463550	t	2025-11-08 03:16:20.120805	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Doulin's Legacy", "position": "Managing director"}	2025-11-08 03:16:20.120805	2025-11-08 03:16:20.120805	kacylyna@gmail.com	60168463550	kacylina jakol	\N
1508	6d28fa38-4354-4c0c-a2dc-e3303ee8df25	1	1	\N	Natalia	Natalia660121@gmail.com	601136414880	t	2025-11-08 05:36:36.151659	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:36:36.151659	2025-11-08 05:36:36.151659	natalia660121@gmail.com	601136414880	natalia	\N
1423	97f7cefa-a0bc-4979-b1c4-7e0e4097ccd4	1	1	\N	Ahjiam	ahjiamh@gmail.com	60168316169	t	2025-11-08 03:18:13.456902	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:18:13.456902	2025-11-08 03:18:13.456902	ahjiamh@gmail.com	60168316169	ahjiam	\N
1424	078e6017-9a56-4d14-ac16-31e97f615af4	1	1	\N	Aaron Chong	aaronctviqi@gmail.com	60168361362	t	2025-11-08 03:18:23.99028	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "IQI Realty Sdn Bhd", "position": "Negotiator"}	2025-11-08 03:18:23.99028	2025-11-08 03:18:23.99028	aaronctviqi@gmail.com	60168361362	aaron chong	\N
1427	3fc0f145-9040-439d-a83f-62b6af9b4728	1	1	\N	Fazierah Binti Zulkarnain	fransria86@gmail.com	60163873347	t	2025-11-08 03:19:45.311314	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 03:19:45.311314	2025-11-08 03:19:45.311314	fransria86@gmail.com	60163873347	fazierah binti zulkarnain	\N
1428	8493a042-61eb-4d77-b554-dfb364c30f27	1	1	\N	Chin	slchin168@gmail.com	60189699139	t	2025-11-08 03:19:53.601251	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:19:53.601251	2025-11-08 03:19:53.601251	slchin168@gmail.com	60189699139	chin	\N
1430	38591fc0-9a01-4a10-934a-83a710c37ad5	1	1	\N	Fairus	alrasul6809@gmail.com	60178649225	t	2025-11-08 03:20:40.01554	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 03:20:40.01554	2025-11-08 03:20:40.01554	alrasul6809@gmail.com	60178649225	fairus	\N
1431	5b2fb593-6e4f-4140-abc3-af956f4298fe	1	1	\N	Chia Swee Chung	chiascg@gmail.com	60128268980	t	2025-11-08 03:23:13.495517	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Hii & Lee", "position": "Manager"}	2025-11-08 03:23:13.495517	2025-11-08 03:23:13.495517	chiascg@gmail.com	60128268980	chia swee chung	\N
1432	ca4de52f-86ff-4f72-a5da-2e2753f69525	1	1	\N	Nur Has Ain Chang	hhassiey19@gmail.com	601136873674	t	2025-11-08 03:23:28.679367	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 03:23:28.679367	2025-11-08 03:23:28.679367	hhassiey19@gmail.com	601136873674	nur has ain chang	\N
1433	7c31df30-d488-47a9-ac9a-5495b5ff3e36	1	1	\N	Elvin Chang	rmccy8894@gmail.com	60146365235	t	2025-11-08 03:24:28.699968	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 03:24:28.699968	2025-11-08 03:24:28.699968	rmccy8894@gmail.com	60146365235	elvin chang	\N
1435	55a9b215-d6b8-4f77-b716-8121746b2ff8	1	1	\N	Siti Zainab Binti Saidin	sizasa1174@gmail.com	601139228024	t	2025-11-08 03:30:09.471023	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 03:30:09.471023	2025-11-08 03:30:09.471023	sizasa1174@gmail.com	601139228024	siti zainab binti saidin	\N
1438	709a71d5-949e-4614-969f-507d6070a569	1	1	\N	Justin Janath	janath.charles83@gmail.com	60178389511	t	2025-11-08 03:33:30.139381	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "TS Biz Academy", "position": "Senior Trainer"}	2025-11-08 03:33:30.139381	2025-11-08 03:33:30.139381	janath.charles83@gmail.com	60178389511	justin janath	\N
1441	f8e7cd20-7613-4b21-9cc8-f47d4901dead	1	1	\N	Wan Zai	wanzw23@gmail.com	60138674596	t	2025-11-08 03:37:16.541019	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "Na"}	2025-11-08 03:37:16.541019	2025-11-08 03:37:16.541019	wanzw23@gmail.com	60138674596	wan zai	\N
1442	ac218023-7cc1-4598-b3b8-5c5d714dd3aa	1	1	\N	Rass Enterprise	rose_6454@ymail.com	60168026454	t	2025-11-08 03:37:32.378149	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 03:37:32.378149	2025-11-08 03:37:32.378149	rose_6454@ymail.com	60168026454	rass enterprise	\N
1443	a8785991-4df2-4564-bf8c-1c1343bd6eab	1	1	\N	Sharon Ho	Carntelle@gmail.com	60178151178	t	2025-11-08 03:39:01.207449	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 03:39:01.207449	2025-11-08 03:39:01.207449	carntelle@gmail.com	60178151178	sharon ho	\N
1446	6ad02fbf-58ef-420b-9f64-9afbcb82a9b3	1	1	\N	Xavier Yap	beverlyyap90@gmail.com	60168302980	t	2025-11-08 03:43:37.677305	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Prestodent Sdn Bhd", "position": "Sales executive"}	2025-11-08 03:43:37.677305	2025-11-08 03:43:37.677305	beverlyyap90@gmail.com	60168302980	xavier yap	\N
1447	a03e76fc-7aed-45ad-b1bf-836c185e7e2a	1	1	\N	Juriah Kulabid	jue249@ymail.com	601120799908	t	2025-11-08 03:44:35.610734	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:44:35.610734	2025-11-08 03:44:35.610734	jue249@ymail.com	601120799908	juriah kulabid	\N
1448	5725c9b2-fbff-47ae-96e0-d77b05421e3b	1	1	\N	Chaw Chee Ming	yangyating@livemail.tw	60168109783	t	2025-11-08 03:45:49.487236	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:45:49.487236	2025-11-08 03:45:49.487236	yangyating@livemail.tw	60168109783	chaw chee ming	\N
1449	e5b6d48c-f2f6-42d0-9353-5dc83df50ef8	1	1	\N	Kai Xin	Kxlim1201@gmail.con	60167767863	t	2025-11-08 03:45:50.690175	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 03:45:50.690175	2025-11-08 03:45:50.690175	kxlim1201@gmail.con	60167767863	kai xin	\N
1450	6498006c-91f4-4b4e-9abf-24b2fcc08881	1	1	\N	Veronica	Veronica_oyf211@hotmail.com	60128962980	t	2025-11-08 03:46:05.647627	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 03:46:05.647627	2025-11-08 03:46:05.647627	veronica_oyf211@hotmail.com	60128962980	veronica	\N
1453	3dcbf606-6617-4a84-aef2-0215843ec7bf	1	1	\N	Zulhilmi Bokhari	Joel7bountyhunter@gmail.com	601137576088	t	2025-11-08 04:01:26.718945	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Techiepreneur trading", "position": "Exec"}	2025-11-08 04:01:26.718945	2025-11-08 04:01:26.718945	joel7bountyhunter@gmail.com	601137576088	zulhilmi bokhari	\N
1454	4838912c-1e10-48e4-9f0d-b5a8435cb489	1	1	\N	Albert Chia	albertchia44@gmail.com	60138832212	t	2025-11-08 04:10:09.655906	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Treeline Urban Boutique lnn hotel ", "position": "Management staff"}	2025-11-08 04:10:09.655906	2025-11-08 04:10:09.655906	albertchia44@gmail.com	60138832212	albert chia	\N
1456	73d33219-634e-446e-a253-26b4adfcea61	1	1	\N	Chacha	kylasamantha1@gmail.com	601162118918	t	2025-11-08 04:11:09.956169	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ysg Bioscape sdn bhd", "position": "Nursery "}	2025-11-08 04:11:09.956169	2025-11-08 04:11:09.956169	kylasamantha1@gmail.com	601162118918	chacha	\N
1457	6dff9fd1-8525-41c7-86e6-a3d231b975a3	1	1	\N	Christhy	christhyafim@gmail.com	601116210072	t	2025-11-08 04:11:31.995843	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ysg bioscape sdn bhd", "position": "nusery"}	2025-11-08 04:11:31.995843	2025-11-08 04:11:31.995843	christhyafim@gmail.com	601116210072	christhy	\N
1458	ee649e54-6a62-43e5-bba3-d5a8e6bee48b	1	1	\N	Chung Vui Lin	haoyun65@hotmail.com	60138717868	t	2025-11-08 04:11:47.101086	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 04:11:47.101086	2025-11-08 04:11:47.101086	haoyun65@hotmail.com	60138717868	chung vui lin	\N
1459	0351da78-9a6a-4d40-b491-f452ac497165	1	1	\N	Chung Seen Fui	seenfui@hotmail.com	60198971748	t	2025-11-08 04:12:11.971278	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 04:12:11.971278	2025-11-08 04:12:11.971278	seenfui@hotmail.com	60198971748	chung seen fui	\N
1462	7f8c7e0a-e317-42d9-b488-dd3f466f6a26	1	1	\N	Asrafzubaidah Abdullah	asrafzubaidah93@gmail.com	60149722564	t	2025-11-08 04:14:57.338905	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mothers Home", "position": "Coordinator"}	2025-11-08 04:14:57.338905	2025-11-08 04:14:57.338905	asrafzubaidah93@gmail.com	60149722564	asrafzubaidah abdullah	\N
1463	4998afa5-4320-48ab-9af5-b9823f7b2f31	1	1	\N	Steward	Steward_707@hotmail.com	60194878228	t	2025-11-08 04:16:08.46672	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 04:16:08.46672	2025-11-08 04:16:08.46672	steward_707@hotmail.com	60194878228	steward	\N
1572	15c41861-a4b8-4acd-bc94-33eb61f3237b	1	1	\N	Liew	empm@gmail.com	60107878978	t	2025-11-08 06:33:49.408704	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:33:49.408704	2025-11-08 06:33:49.408704	empm@gmail.com	60107878978	liew	\N
1464	27732d13-eadf-4799-95e2-be55ff6b9426	1	1	\N	Doris Lim	siewkui@yahoo.com	60168311943	t	2025-11-08 04:17:04.637128	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Doris & Associates ", "position": "Image consultant "}	2025-11-08 04:17:04.637128	2025-11-08 04:17:04.637128	siewkui@yahoo.com	60168311943	doris lim	\N
1465	4f92f3d6-6b3b-4e93-8837-0ba4d94c01b3	1	1	\N	Irene Liew	irenel2001@yahoo.co.uk	60178170301	t	2025-11-08 04:17:43.423334	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Future base enricher ", "position": "Director"}	2025-11-08 04:17:43.423334	2025-11-08 04:17:43.423334	irenel2001@yahoo.co.uk	60178170301	irene liew	\N
1466	7201f5e6-80f1-434f-b2aa-6ec2bc88724d	1	1	\N	Junaidi Jalli	edycartrade@gmail.com	60147725988	t	2025-11-08 04:25:33.736272	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 04:25:33.736272	2025-11-08 04:25:33.736272	edycartrade@gmail.com	60147725988	junaidi jalli	\N
1467	efec1b02-3686-4233-8883-5756b243a86a	1	1	\N	Eddie	f.y.t_95@hotmail.com	60109314330	t	2025-11-08 04:25:35.171964	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Tee Global Affiliate", "position": "Personal"}	2025-11-08 04:25:35.171964	2025-11-08 04:25:35.171964	f.y.t_95@hotmail.com	60109314330	eddie	\N
1469	8cf22e64-61a5-4c7c-aa21-ac1360b677e5	1	1	\N	Thien Mui Lin	theresa.thien@gmail.com	60138667011	t	2025-11-08 04:30:37.234669	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 04:30:37.234669	2025-11-08 04:30:37.234669	theresa.thien@gmail.com	60138667011	thien mui lin	\N
1470	4214d8ff-9f97-4170-b633-ea005b91c322	1	1	\N	Brian Hong	Brianhong844t@gmail.com	60146554831	t	2025-11-08 04:34:26.52814	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 04:34:26.52814	2025-11-08 04:34:26.52814	brianhong844t@gmail.com	60146554831	brian hong	\N
1472	f1dc8bd3-f05b-4bba-b213-0e321bad42d4	1	1	\N	May	mommeivei@gmail.com	60109489880	t	2025-11-08 04:42:02.41476	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MOM Designer House", "position": "Sales and Account Executive"}	2025-11-08 04:42:02.41476	2025-11-08 04:42:02.41476	mommeivei@gmail.com	60109489880	may	\N
1473	36f75a9f-efeb-4276-9d1d-9065582d048e	1	1	\N	Kevy	momkevy@gmail.com	60164170566	t	2025-11-08 04:42:29.849024	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mom designer house", "position": "Assistance senior interior designer"}	2025-11-08 04:42:29.849024	2025-11-08 04:42:29.849024	momkevy@gmail.com	60164170566	kevy	\N
1474	d68844c8-ee76-4a5d-add1-c774f8be4b0f	1	1	\N	Jovanne Wong	jovanne.wong@gmail.com	60138365150	t	2025-11-08 04:43:43.406406	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MOM Designer House", "position": "Senior Interior Designer"}	2025-11-08 04:43:43.406406	2025-11-08 04:43:43.406406	jovanne.wong@gmail.com	60138365150	jovanne wong	\N
1475	0960bd23-6042-4237-91ea-2fbae21bafd9	1	1	\N	Christella	momchris@gmail.com	601136330148	t	2025-11-08 04:44:13.399963	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MOM DESIGNER HOUSE", "position": "Designer"}	2025-11-08 04:44:13.399963	2025-11-08 04:44:13.399963	momchris@gmail.com	601136330148	christella	\N
1476	3565ee9f-6bc9-4c43-9e6a-5fb839e2efd5	1	1	\N	Natalie	momnatalie00@gmail.com	60142014223	t	2025-11-08 04:44:29.038463	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mom Designer House", "position": "Interior Design"}	2025-11-08 04:44:29.038463	2025-11-08 04:44:29.038463	momnatalie00@gmail.com	60142014223	natalie	\N
1477	17d9118e-e69b-4a31-a701-3f43684b0dc3	1	1	\N	Rachel Chin	momrachelchin@gmail.com	60163318965	t	2025-11-08 04:45:25.725547	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mom designer house", "position": "Interior designer"}	2025-11-08 04:45:25.725547	2025-11-08 04:45:25.725547	momrachelchin@gmail.com	60163318965	rachel chin	\N
1479	ee1376dc-87d2-45e8-8c1f-01713ef227c7	1	1	\N	Rahim Bin Awang	rahimawang60im@gmail.com	601155831007	t	2025-11-08 04:47:23.778984	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "AraARA ENTERPRISE", "position": "PENGARAH @ PEMILIK"}	2025-11-08 04:47:23.778984	2025-11-08 04:47:23.778984	rahimawang60im@gmail.com	601155831007	rahim bin awang	\N
1480	2b45407e-642c-498e-88b2-40a4cad63e58	1	1	\N	Clarance Udan	claranceudan@yahoo.com	60168325587	t	2025-11-08 04:48:10.769672	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "CLP Enterprise", "position": "Sole proprietor"}	2025-11-08 04:48:10.769672	2025-11-08 04:48:10.769672	claranceudan@yahoo.com	60168325587	clarance udan	\N
1481	ea977250-c269-4ab1-86a1-d541d923b4ce	1	1	\N	Lu Yin Yen	yinyenlu@gmail.com	60168458669	t	2025-11-08 04:53:56.900885	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Cloudside", "position": "Sole proprietor"}	2025-11-08 04:53:56.900885	2025-11-08 04:53:56.900885	yinyenlu@gmail.com	60168458669	lu yin yen	\N
1482	e021b704-38b3-47e0-a376-24b9640ebf3f	1	1	\N	Shania Leong	shaniaxxd2@gmail.com	60163961031	t	2025-11-08 04:54:13.260648	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Cloudside", "position": "Sole Proprietor"}	2025-11-08 04:54:13.260648	2025-11-08 04:54:13.260648	shaniaxxd2@gmail.com	60163961031	shania leong	\N
1483	1587c1ed-595d-42e1-bcb1-9b9c43fee63b	1	1	\N	Mohammad Sukri Bin Umar	mshu7209@gmail.com	60168307209	t	2025-11-08 04:55:10.285755	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MADSHUKV INNOVATION CONSULTANT SDN BHD", "position": "Manager"}	2025-11-08 04:55:10.285755	2025-11-08 04:55:10.285755	mshu7209@gmail.com	60168307209	mohammad sukri bin umar	\N
1490	a8216b1e-d47d-4e43-812e-eb2834986cbe	1	1	\N	Florence Wee	florence.wee@fordeco.com	60168332260	t	2025-11-08 05:07:21.915326	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Fordeco Construction Sdn Bhd ", "position": "Account "}	2025-11-08 05:07:21.915326	2025-11-08 05:07:21.915326	florence.wee@fordeco.com	60168332260	florence wee	\N
1491	2fa6e68a-4254-4008-a4da-6503a623754f	1	1	\N	Rice Chong	chongseihung@gmail.com	60168332172	t	2025-11-08 05:07:39.22421	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Borneo Culinary Association Sabah & Sarawak", "position": "Vice President"}	2025-11-08 05:07:39.22421	2025-11-08 05:07:39.22421	chongseihung@gmail.com	60168332172	rice chong	\N
1492	8d864043-7a42-40f1-9f95-558f3c242843	1	1	\N	Emy Lydia	emy.tgv@gmail.com	60178106020	t	2025-11-08 05:08:09.632125	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Triea Global Venture", "position": "Marketer"}	2025-11-08 05:08:09.632125	2025-11-08 05:08:09.632125	emy.tgv@gmail.com	60178106020	emy lydia	\N
1493	1b4833c1-8ecc-4a61-8b73-fdda32e98259	1	1	\N	Vinna	Vinnayupin@yahoo.com	60198731336	t	2025-11-08 05:11:30.706836	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "Na"}	2025-11-08 05:11:30.706836	2025-11-08 05:11:30.706836	vinnayupin@yahoo.com	60198731336	vinna	\N
1494	802322d3-d80b-4a32-9b6c-4ee2ce06360a	1	1	\N	Stephanie Wong	Chiawvai@gmail.com	60128278633	t	2025-11-08 05:13:25.737258	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "Na"}	2025-11-08 05:13:25.737258	2025-11-08 05:13:25.737258	chiawvai@gmail.com	60128278633	stephanie wong	\N
1496	96ac614f-658b-4789-83ab-7374e23e8d75	1	1	\N	Nurzanah	Bdzanalyka@gmail.com	60123812428	t	2025-11-08 05:17:15.325022	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Person ", "position": "Personal "}	2025-11-08 05:17:15.325022	2025-11-08 05:17:15.325022	bdzanalyka@gmail.com	60123812428	nurzanah	\N
1497	9b7d932c-391f-465a-9435-4e123b206d05	1	1	\N	Eric Chua Zheng Hua	ericchua94@gmail.com	60126673697	t	2025-11-08 05:22:46.693072	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MEGARICH DEVELOPMENT SDN BHD", "position": "Visitor"}	2025-11-08 05:22:46.693072	2025-11-08 05:22:46.693072	ericchua94@gmail.com	60126673697	eric chua zheng hua	\N
1498	589c0e8b-e0fb-4cf7-b82e-cc57ee3fc77d	1	1	\N	Nelson Voo	Nelsonvst@gmail.com	60168122688	t	2025-11-08 05:23:54.238927	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Golden ox enterprise", "position": "Bossku"}	2025-11-08 05:23:54.238927	2025-11-08 05:23:54.238927	nelsonvst@gmail.com	60168122688	nelson voo	\N
1499	70ecbd17-ef2f-4e28-9859-91b1569dbf01	1	1	\N	Leonard Tabaf	Leonard.tabad@gmail.com	601120881540	t	2025-11-08 05:24:04.953717	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Petronas", "position": "Senior Executive"}	2025-11-08 05:24:04.953717	2025-11-08 05:24:04.953717	leonard.tabad@gmail.com	601120881540	leonard tabaf	\N
1500	2f28a3ae-ffbf-4798-859a-637883eab583	1	1	\N	Saifulbahri	drsaifulbahri@gmail.com	60168301548	t	2025-11-08 05:25:20.94371	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "S&J Legacy Sdn Bhd", "position": "Director"}	2025-11-08 05:25:20.94371	2025-11-08 05:25:20.94371	drsaifulbahri@gmail.com	60168301548	saifulbahri	\N
1503	f9a92d0d-62be-4841-b6bf-2783d4bc10b9	1	1	\N	Fatihah	Zaharifatihah24@gmail.com	60198836354	t	2025-11-08 05:32:02.151874	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 05:32:02.151874	2025-11-08 05:32:02.151874	zaharifatihah24@gmail.com	60198836354	fatihah	\N
1504	320d02b7-5407-40df-9a4f-1a4838ab4bd8	1	1	\N	Ahmad Kamarul Azuan Bin Idris	iwan910113@gmail.com	601116453581	t	2025-11-08 05:32:38.163762	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "No"}	2025-11-08 05:32:38.163762	2025-11-08 05:32:38.163762	iwan910113@gmail.com	601116453581	ahmad kamarul azuan bin idris	\N
1505	3ef92d70-fcbe-4d52-b379-235b21c410ab	1	1	\N	Sunarti Binti Yussof	Sunartiyussof@gmail.com	60168058605	t	2025-11-08 05:32:55.30868	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 05:32:55.30868	2025-11-08 05:32:55.30868	sunartiyussof@gmail.com	60168058605	sunarti binti yussof	\N
1506	baac6632-f01c-44b7-9fce-a25518a04c51	1	1	\N	Nicolas Basalik Robin	nr27506@gmail.com	601139207302	t	2025-11-08 05:34:38.38154	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:34:38.38154	2025-11-08 05:34:38.38154	nr27506@gmail.com	601139207302	nicolas basalik robin	\N
1507	ae2142d5-e435-4c42-92c5-b8333d04b73d	1	1	\N	Luke	lukesitaim93@gmail.com	601131482927	t	2025-11-08 05:34:53.687507	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:34:53.687507	2025-11-08 05:34:53.687507	lukesitaim93@gmail.com	601131482927	luke	\N
1509	bcbac13c-fbf5-42c3-a285-5a3de2ce1c55	1	1	\N	Amy	thamamy06@gmail.com	60167726354	t	2025-11-08 05:36:43.088453	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:36:43.088453	2025-11-08 05:36:43.088453	thamamy06@gmail.com	60167726354	amy	\N
1510	668fa0aa-bd45-4d1c-b54b-44d99aca2a08	1	1	\N	Ivan Raul Ling Bi Hwa	ivanraul.ling@torr.com.my	60198896830	t	2025-11-08 05:38:18.220198	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Torr Energy", "position": "Marketing & Multimedia Support"}	2025-11-08 05:38:18.220198	2025-11-08 05:38:18.220198	ivanraul.ling@torr.com.my	60198896830	ivan raul ling bi hwa	\N
1511	8f606d32-897d-4888-aa73-e4f8cf152ad8	1	1	\N	Suziana	suzianamaslun2399@gmail.com	601126892399	t	2025-11-08 05:38:59.423059	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:38:59.423059	2025-11-08 05:38:59.423059	suzianamaslun2399@gmail.com	601126892399	suziana	\N
1512	fc530ba9-c221-47fc-94fb-e6f2a4aa6d56	1	1	\N	Nurin Farzana	Nurin.farzana@torr.com.my	60123793357	t	2025-11-08 05:39:38.539173	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Torr energy sdn bhd", "position": "Hr"}	2025-11-08 05:39:38.539173	2025-11-08 05:39:38.539173	nurin.farzana@torr.com.my	60123793357	nurin farzana	\N
1514	4548817f-0142-4e3a-80b7-a1c06810ab36	1	1	\N	Kim Shasha	green_shasha90@yahoo.com	601133709180	t	2025-11-08 05:41:11.196737	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 05:41:11.196737	2025-11-08 05:41:11.196737	green_shasha90@yahoo.com	601133709180	kim shasha	\N
1515	d9bf6451-1766-4fc5-bc08-6bd2f7686715	1	1	\N	Tan Chee Ooi	cheeooi2827@gmail.com	60178397998	t	2025-11-08 05:41:12.046911	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 05:41:12.046911	2025-11-08 05:41:12.046911	cheeooi2827@gmail.com	60178397998	tan chee ooi	\N
1517	eb7becc2-3c6e-4024-afab-236ae113667c	1	1	\N	Lucy Wong	luckypink219lw@gmail.com	60168288296	t	2025-11-08 05:42:31.547545	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Amway", "position": "Business owner"}	2025-11-08 05:42:31.547545	2025-11-08 05:42:31.547545	luckypink219lw@gmail.com	60168288296	lucy wong	\N
1518	273762cf-671f-4a34-a676-18b559edd3ce	1	1	\N	Brian	zhenmin92@hotmail.com	60128011235	t	2025-11-08 05:43:40.179141	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:43:40.179141	2025-11-08 05:43:40.179141	zhenmin92@hotmail.com	60128011235	brian	\N
1519	8d38ea8b-3ae9-4a85-b4c7-9be2faf4ecc8	1	1	\N	Tina	Celestinapwj@gmail.com	601133633013	t	2025-11-08 05:43:41.27802	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:43:41.27802	2025-11-08 05:43:41.27802	celestinapwj@gmail.com	601133633013	tina	\N
1520	483a870e-fe57-42da-a522-c2f8d59785f6	1	1	\N	Goh Jein Chian	Chenkorgoh@gmail.con	60124085478	t	2025-11-08 05:44:06.666223	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 05:44:06.666223	2025-11-08 05:44:06.666223	chenkorgoh@gmail.con	60124085478	goh jein chian	\N
1521	bddf784c-a0ed-4218-acd5-4e9607f781d9	1	1	\N	Evelyn Ti	evelynnti@gmail.com	60168363291	t	2025-11-08 05:46:14.211252	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Tinun Kejuruteraan ", "position": "Manager"}	2025-11-08 05:46:14.211252	2025-11-08 05:46:14.211252	evelynnti@gmail.com	60168363291	evelyn ti	\N
1522	0cf1652f-c9e2-4190-8697-8b513daef771	1	1	\N	Lee	reprojectssb@gmail.com	60198602200	t	2025-11-08 05:46:24.673957	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "RE Projects", "position": "Manager"}	2025-11-08 05:46:24.673957	2025-11-08 05:46:24.673957	reprojectssb@gmail.com	60198602200	lee	\N
1523	dd6d1a48-1e93-4393-97ee-07abc324a392	1	1	\N	Liew Kar Liong	Arthur.liewkl@gmail.com	60138889669	t	2025-11-08 05:51:27.280611	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Techtitan", "position": "Director"}	2025-11-08 05:51:27.280611	2025-11-08 05:51:27.280611	arthur.liewkl@gmail.com	60138889669	liew kar liong	\N
1524	2f5809bc-67f8-40c3-bc1b-037a195d9a8f	1	1	\N	Nurfatihah Fatin	ftihhftin@gmail.com	601133271627	t	2025-11-08 05:53:32.451702	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 05:53:32.451702	2025-11-08 05:53:32.451702	ftihhftin@gmail.com	601133271627	nurfatihah fatin	\N
1525	07ba15f2-26ab-480c-9968-5059c2933ace	1	1	\N	Siti Rabiahtul Adawiyah	Rabiahtul2107@gmail.com	601136339710	t	2025-11-08 05:53:36.739374	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "N/A", "position": "N/A"}	2025-11-08 05:53:36.739374	2025-11-08 05:53:36.739374	rabiahtul2107@gmail.com	601136339710	siti rabiahtul adawiyah	\N
1526	c419cbf9-06c4-4343-8dcd-0791393eabaf	1	1	\N	Asrina	rinaasrina751@gmail.com	60168259704	t	2025-11-08 05:53:59.735802	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 05:53:59.735802	2025-11-08 05:53:59.735802	rinaasrina751@gmail.com	60168259704	asrina	\N
1527	405f765d-0cd4-46ee-aca7-3e2864446d69	1	1	\N	Mohd Shah Rizad	rinaasrina751@gmail.com	60168251364	t	2025-11-08 05:54:05.881648	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 05:54:05.881648	2025-11-08 05:54:05.881648	rinaasrina751@gmail.com	60168251364	mohd shah rizad	\N
1528	a9be6549-b454-4057-a2aa-f637f81ccba8	1	1	\N	Irenizar Binti Saripin	Milahraimie@gmail.com	60102139462	t	2025-11-08 05:57:39.146437	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 05:57:39.146437	2025-11-08 05:57:39.146437	milahraimie@gmail.com	60102139462	irenizar binti saripin	\N
1529	525b72d8-644a-45ea-b502-b4a098c60a05	1	1	\N	Asiah Othman	ash.jpmedresources@gmail.com	60168384291	t	2025-11-08 05:59:09.802612	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "JASH PILLAY MEDRESOURCES SDN BHD ", "position": "Director"}	2025-11-08 05:59:09.802612	2025-11-08 05:59:09.802612	ash.jpmedresources@gmail.com	60168384291	asiah othman	\N
1530	8c155999-2381-4aec-8405-0e126ab2deac	1	1	\N	Jason Jimmy Lee Pillay	Jasonpillay88@gmail.com	60102364291	t	2025-11-08 05:59:13.128718	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "JPM MEDRESOURCES  SDN BHD", "position": "Ceo"}	2025-11-08 05:59:13.128718	2025-11-08 05:59:13.128718	jasonpillay88@gmail.com	60102364291	jason jimmy lee pillay	\N
1531	a8e52221-5d27-4f54-bf8c-6c3d85606678	1	1	\N	Nolla Avilla	evanovella25@gmail.com	60135764127	t	2025-11-08 05:59:41.612679	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 05:59:41.612679	2025-11-08 05:59:41.612679	evanovella25@gmail.com	60135764127	nolla avilla	\N
1532	adaaaae2-3872-42f4-b33d-6d0d9fb99a80	1	1	\N	Dimas Andrian Bin Ansar	edrianislam@gmail.com	60198956603	t	2025-11-08 05:59:46.547703	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "kupi kampung", "position": "owner"}	2025-11-08 05:59:46.547703	2025-11-08 05:59:46.547703	edrianislam@gmail.com	60198956603	dimas andrian bin ansar	\N
1533	027655cf-5b58-4d46-b2c3-e97f6df39eae	1	1	\N	Mohamad Rizki	riskyjurah@gmail.com	601160967426	t	2025-11-08 05:59:50.609959	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 05:59:50.609959	2025-11-08 05:59:50.609959	riskyjurah@gmail.com	601160967426	mohamad rizki	\N
1535	2622adea-9504-4826-9033-28392ceb109f	1	1	\N	Lydia Chin	Fererozy@hotmail.com	60172377912	t	2025-11-08 06:00:41.298574	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:00:41.298574	2025-11-08 06:00:41.298574	fererozy@hotmail.com	60172377912	lydia chin	\N
1536	cb5e9b2a-e54a-4552-97b6-2e1b6319cd3d	1	1	\N	William Cheong	Will_wui11@hotmail.com	60168039811	t	2025-11-08 06:00:58.045059	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:00:58.045059	2025-11-08 06:00:58.045059	will_wui11@hotmail.com	60168039811	william cheong	\N
1537	4af60fd8-d321-46d1-95bd-c65049a9ed95	1	1	\N	Elise Yong	yongelise711@gmail.com	601136780711	t	2025-11-08 06:01:33.250791	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:01:33.250791	2025-11-08 06:01:33.250791	yongelise711@gmail.com	601136780711	elise yong	\N
1538	86d3b99e-fa34-417e-b316-6eda019ef729	1	1	\N	Waran	waranyong@gmail.com	60168462272	t	2025-11-08 06:02:22.50607	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:02:22.50607	2025-11-08 06:02:22.50607	waranyong@gmail.com	60168462272	waran	\N
1544	ddae616d-2f1d-4833-bf6b-cf97464a4736	1	1	\N	Shaelah Binti Kuta	ayie_cla1988@yahoo.com.my	60143581288	t	2025-11-08 06:05:37.670555	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 06:05:37.670555	2025-11-08 06:05:37.670555	ayie_cla1988@yahoo.com.my	60143581288	shaelah binti kuta	\N
1545	b98d670a-0954-4692-a8c5-02acac8b7a33	1	1	\N	Sk Nexilis	oleylizz0138705066@gmail.com	601131843822	t	2025-11-08 06:06:49.032651	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:06:49.032651	2025-11-08 06:06:49.032651	oleylizz0138705066@gmail.com	601131843822	sk nexilis	\N
1546	bf9869d1-499f-4d2d-bbfb-f96e74a23e9b	1	1	\N	Muhammad Amir Bin Mohd Azman	Azmanamir.work.1995@gmail.com	60139730031	t	2025-11-08 06:06:57.560649	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:06:57.560649	2025-11-08 06:06:57.560649	azmanamir.work.1995@gmail.com	60139730031	muhammad amir bin mohd azman	\N
1547	6d916694-36ac-465d-9ab9-665022141a14	1	1	\N	Chang Jean Yean	Jeanyeanchang@gmail.com	60109418463	t	2025-11-08 06:07:08.435873	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:07:08.435873	2025-11-08 06:07:08.435873	jeanyeanchang@gmail.com	60109418463	chang jean yean	\N
1548	7b5cc30f-14f1-4a50-a241-b8f50eee4275	1	1	\N	S. Ahmad	scholars.assist@gmail.com	60162747058	t	2025-11-08 06:07:39.733884	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MSV Engineering Sdn. Bhd.", "position": "Manager"}	2025-11-08 06:07:39.733884	2025-11-08 06:07:39.733884	scholars.assist@gmail.com	60162747058	s. ahmad	\N
1549	3b41b6a8-c875-4352-97b8-c57e2eef1416	1	1	\N	Loh Yung Hao	yunghao429@gmail.com	60105642833	t	2025-11-08 06:08:21.649875	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "IRBM", "position": "Executive Officer"}	2025-11-08 06:08:21.649875	2025-11-08 06:08:21.649875	yunghao429@gmail.com	60105642833	loh yung hao	\N
1550	404e0b25-b5e7-4dc8-a776-fc8ed73bb985	1	1	\N	Eliza	elizayeels@gmail.com	60178518788	t	2025-11-08 06:09:16.560619	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "JKM", "position": "Executive"}	2025-11-08 06:09:16.560619	2025-11-08 06:09:16.560619	elizayeels@gmail.com	60178518788	eliza	\N
1551	cc3d6978-1255-43f8-8580-3f7f0f6ca8c7	1	1	\N	Datuk Adeline Leong	adelinepungleong@gmail.com	60198539922	t	2025-11-08 06:11:01.302677	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "IEC Sdn Bhd", "position": "Director"}	2025-11-08 06:11:01.302677	2025-11-08 06:11:01.302677	adelinepungleong@gmail.com	60198539922	datuk adeline leong	\N
1552	90df6375-9053-47b3-9fe1-61c3fff0f9c4	1	1	\N	Fenella Joni Sabin	fenellajsxo@gmail.com	60168440376	t	2025-11-08 06:16:28.645503	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SDS ADVANCE SDN BHD", "position": "Assistant Manager Business Development"}	2025-11-08 06:16:28.645503	2025-11-08 06:16:28.645503	fenellajsxo@gmail.com	60168440376	fenella joni sabin	\N
1553	3d3e9e27-34ab-40fc-b2ad-79f3cdab6da9	1	1	\N	Crystal Ong	jing123_92@hotmail.com	60143171330	t	2025-11-08 06:18:15.225993	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Outfitters Borneo Sdn Bhd", "position": "Account"}	2025-11-08 06:18:15.225993	2025-11-08 06:18:15.225993	jing123_92@hotmail.com	60143171330	crystal ong	\N
1554	01e7edb5-9eed-4b5d-b79b-4e8b34cb8c46	1	1	\N	Syamsul	Syamsul.amar@gmail.com	60195883030	t	2025-11-08 06:19:15.561438	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Classix kopitiam sdn bhd", "position": "Director"}	2025-11-08 06:19:15.561438	2025-11-08 06:19:15.561438	syamsul.amar@gmail.com	60195883030	syamsul	\N
1555	efcfb095-30ba-452e-9f32-631644f43745	1	1	\N	Louie Carreon	Louie_love30@yahoo.com	60188709720	t	2025-11-08 06:21:08.868869	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sanny Enterprise", "position": "Secretary"}	2025-11-08 06:21:08.868869	2025-11-08 06:21:08.868869	louie_love30@yahoo.com	60188709720	louie carreon	\N
1556	eb27d237-50dd-4b87-af65-1bd3bf07d91e	1	1	\N	Afifi	eppytheprince@gmail.com	60145164320	t	2025-11-08 06:21:22.251742	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Smkakk", "position": "-"}	2025-11-08 06:21:22.251742	2025-11-08 06:21:22.251742	eppytheprince@gmail.com	60145164320	afifi	\N
1557	a7097b6c-d718-4232-9c8c-445a815a0ccf	1	1	\N	Saniah Binti Masa @basah	sannyenterprise99@gmail.com	60168030493	t	2025-11-08 06:22:07.495541	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sanny Enterprise ", "position": "Ceo"}	2025-11-08 06:22:07.495541	2025-11-08 06:22:07.495541	sannyenterprise99@gmail.com	60168030493	saniah binti masa @basah	\N
1559	fbbf55dc-16b3-418d-ae6a-c7a85e9c5476	1	1	\N	Marilou Boquiron	boquironmarilou@yahoo.com	601136603527	t	2025-11-08 06:22:25.403325	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sanny enterprise", "position": "Secretary"}	2025-11-08 06:22:25.403325	2025-11-08 06:22:25.403325	boquironmarilou@yahoo.com	601136603527	marilou boquiron	\N
1560	3955dacc-38ea-445b-9a31-56a2ff8685f5	1	1	\N	Marc Zaafir	marcfaustein1911@gmail.com	60189617873	t	2025-11-08 06:23:12.32869	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Carri Oil and Gas Sdn Bhd ", "position": "COO"}	2025-11-08 06:23:12.32869	2025-11-08 06:23:12.32869	marcfaustein1911@gmail.com	60189617873	marc zaafir	\N
1561	37763430-6d71-497e-a93f-c95bc4d5c3da	1	1	\N	Mohd Hafsan Bin Hussein	mohdhafsanh@gmail.com	601125244154	t	2025-11-08 06:24:32.610327	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:24:32.610327	2025-11-08 06:24:32.610327	mohdhafsanh@gmail.com	601125244154	mohd hafsan bin hussein	\N
1562	e2cbfdef-1624-41ba-a72f-ebe10ef94111	1	1	\N	Calvin Quek	Majsticleisurebki@gmail.com	60168310768	t	2025-11-08 06:25:43.392688	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Majestic Leisure and Tours ", "position": "Manager"}	2025-11-08 06:25:43.392688	2025-11-08 06:25:43.392688	majsticleisurebki@gmail.com	60168310768	calvin quek	\N
1563	080fdbd3-d3d8-4873-9e8c-36291bcb4aba	1	1	\N	Michael Wong Ho On	miwongkk@gmail.com	60168269175	t	2025-11-08 06:26:30.399111	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Tune Protect Malaysia Berhad", "position": "Senior Manager"}	2025-11-08 06:26:30.399111	2025-11-08 06:26:30.399111	miwongkk@gmail.com	60168269175	michael wong ho on	\N
1564	a6f12f96-1b9b-42cb-84c9-740c24cd9d86	1	1	\N	Leonel	richieleonel05@gmail.com	601126882737	t	2025-11-08 06:26:34.405846	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Tune Protect Malaysia", "position": "Marketing"}	2025-11-08 06:26:34.405846	2025-11-08 06:26:34.405846	richieleonel05@gmail.com	601126882737	leonel	\N
1565	d90eb24c-7263-44e0-b116-b9d004f28b6a	1	1	\N	Mohd Shahrul Bin Tunjol @ Zainal	mohdshahrultunjol@gmail.com	601156828646	t	2025-11-08 06:29:36.409934	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Future Success", "position": "Co owner"}	2025-11-08 06:29:36.409934	2025-11-08 06:29:36.409934	mohdshahrultunjol@gmail.com	601156828646	mohd shahrul bin tunjol @ zainal	\N
1568	aa93747d-92ea-4453-9ccc-193226f6c291	1	1	\N	Bernardette Demon	bernardettedet@yahoo.com	60168287159	t	2025-11-08 06:32:00.383974	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:32:00.383974	2025-11-08 06:32:00.383974	bernardettedet@yahoo.com	60168287159	bernardette demon	\N
1571	807c3215-b019-4400-a69c-ea621b8a7490	1	1	\N	Brenda Sharon Chong Mei Fong	brendasharonchongmeifong@gmail.com	60122628773	t	2025-11-08 06:32:31.994521	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:32:31.994521	2025-11-08 06:32:31.994521	brendasharonchongmeifong@gmail.com	60122628773	brenda sharon chong mei fong	\N
1573	e6885b2d-fb62-4deb-ba3b-2472e5005647	1	1	\N	Sitti Mariam Bt Ismail	anakkimanis87@gmail.com	601130106920	t	2025-11-08 06:34:39.881921	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:34:39.881921	2025-11-08 06:34:39.881921	anakkimanis87@gmail.com	601130106920	sitti mariam bt ismail	\N
1574	f2c3f061-8dda-444d-a20c-42dc08155f07	1	1	\N	Byron Melvin	mbyronbenjamin@gmail.com	601125446171	t	2025-11-08 06:35:57.570808	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah Electricity", "position": "System Analyst"}	2025-11-08 06:35:57.570808	2025-11-08 06:35:57.570808	mbyronbenjamin@gmail.com	601125446171	byron melvin	\N
1575	ae910def-9f0a-4efc-b03d-543d8cf68413	1	1	\N	Vanessa Lo	vanila90@hotmail.com	60109327922	t	2025-11-08 06:36:10.571124	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "VY MARKETING SDN BHD", "position": "Director"}	2025-11-08 06:36:10.571124	2025-11-08 06:36:10.571124	vanila90@hotmail.com	60109327922	vanessa lo	\N
1576	ac3e59dd-4121-4099-a176-6ccc81f2a089	1	1	\N	Racha Mah	liang_lee82@yahoo.com.hk	60168727777	t	2025-11-08 06:36:12.983758	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mah moh hin travel agency", "position": "Manager"}	2025-11-08 06:36:12.983758	2025-11-08 06:36:12.983758	liang_lee82@yahoo.com.hk	60168727777	racha mah	\N
1577	bb3b4597-9c28-4268-8204-f48fa42e7c2e	1	1	\N	Lee Lee	Eeleelee2011@gmail.com	60128286477	t	2025-11-08 06:38:40.524044	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Non", "position": "Nil"}	2025-11-08 06:38:40.524044	2025-11-08 06:38:40.524044	eeleelee2011@gmail.com	60128286477	lee lee	\N
1578	50bb5b2d-8ea7-4847-88ee-9c447958a9a0	1	1	\N	David Tai	ttwdkk@yahoo.com	60128236477	t	2025-11-08 06:38:42.119478	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 06:38:42.119478	2025-11-08 06:38:42.119478	ttwdkk@yahoo.com	60128236477	david tai	\N
1579	27b7f079-19a6-4d84-b413-d0ef23163c94	1	1	\N	Dorothy	dorothywong120194@gmail.com	60168288468	t	2025-11-08 06:44:06.728225	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Kim fah", "position": "Account"}	2025-11-08 06:44:06.728225	2025-11-08 06:44:06.728225	dorothywong120194@gmail.com	60168288468	dorothy	\N
1581	d221d804-ce11-4c7d-8a2d-5ae9615ff7e9	1	1	\N	Musyiri Jarawi	musyirijarawi5212@yahoo.com	60138638083	t	2025-11-08 06:44:55.383336	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:44:55.383336	2025-11-08 06:44:55.383336	musyirijarawi5212@yahoo.com	60138638083	musyiri jarawi	\N
1582	1d636668-63fb-47e6-97b9-8849275ff349	1	1	\N	Aisa	Aisasuke89@yahoo.com	60128502452	t	2025-11-08 06:45:07.635338	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "X", "position": "Ex"}	2025-11-08 06:45:07.635338	2025-11-08 06:45:07.635338	aisasuke89@yahoo.com	60128502452	aisa	\N
1583	74c3e8c6-d9ad-44d1-b625-30072a489355	1	1	\N	Siti Maryam Binti Dawalih	mukhlisah_nur@yahoo.com	601126876763	t	2025-11-08 06:48:43.973707	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "_", "position": "-"}	2025-11-08 06:48:43.973707	2025-11-08 06:48:43.973707	mukhlisah_nur@yahoo.com	601126876763	siti maryam binti dawalih	\N
1584	fb4de76b-64c5-45ee-a693-1c0a62a90534	1	1	\N	Jenifer Julius	jenjulius@gmail.com	60173736778	t	2025-11-08 06:49:10.622573	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "J8 Creative", "position": "Owner"}	2025-11-08 06:49:10.622573	2025-11-08 06:49:10.622573	jenjulius@gmail.com	60173736778	jenifer julius	\N
1585	66466ed2-6b77-4d97-8495-e95651716b73	1	1	\N	Nurul Ain Binti Berudin	ainberudinwirk@gmail.com	601126899814	t	2025-11-08 06:49:42.792979	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:49:42.792979	2025-11-08 06:49:42.792979	ainberudinwirk@gmail.com	601126899814	nurul ain binti berudin	\N
1586	c15e490b-1ac8-4bf3-b436-dd522cf5a627	1	1	\N	Jessica	Jesscindy113@gmail.com	60168331036	t	2025-11-08 06:51:37.043	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:51:37.043	2025-11-08 06:51:37.043	jesscindy113@gmail.com	60168331036	jessica	\N
1587	3fcb040d-bcb7-4323-9c72-08fae0187859	1	1	\N	Ho Kian Vun	Kianvun@gmail.com	601123553133	t	2025-11-08 06:52:59.27256	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Own", "position": "Own"}	2025-11-08 06:52:59.27256	2025-11-08 06:52:59.27256	kianvun@gmail.com	601123553133	ho kian vun	\N
1588	b8904fee-71d3-4de9-bd95-f26b3681911d	1	1	\N	Wong Ching Wee	Aweewcw@gmail.com	60138222228	t	2025-11-08 06:53:11.348804	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Fong Yuan Hung Import and Export  SDN BHD ", "position": "Manager "}	2025-11-08 06:53:11.348804	2025-11-08 06:53:11.348804	aweewcw@gmail.com	60138222228	wong ching wee	\N
1589	a9b44a00-9d9d-49ad-ae59-f2262596aa7c	1	1	\N	Pang Chooi Leng	acelinesabahproperty@gmail.com	60102255208	t	2025-11-08 06:53:58.780183	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Own", "position": "Own"}	2025-11-08 06:53:58.780183	2025-11-08 06:53:58.780183	acelinesabahproperty@gmail.com	60102255208	pang chooi leng	\N
1590	e9362e20-ad11-4219-aad9-55a1086ea2c5	1	1	\N	Rahman Mintek	rahmanmentek@gmail.com	601125256667	t	2025-11-08 06:54:37.097232	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 06:54:37.097232	2025-11-08 06:54:37.097232	rahmanmentek@gmail.com	601125256667	rahman mintek	\N
1591	19e72209-297b-4f7b-891f-90434980c64e	1	1	\N	Anne	wonganne666@gmail.com	60146559266	t	2025-11-08 06:54:48.361282	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "tara international", "position": "intern"}	2025-11-08 06:54:48.361282	2025-11-08 06:54:48.361282	wonganne666@gmail.com	60146559266	anne	\N
1593	2f4593f5-5dc5-457a-9be7-e209295c38f0	1	1	\N	Bryan Sim	Bryansim10@yahoo.com	60162268998	t	2025-11-08 06:57:32.294319	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "KBB ENTERPRISE ", "position": "Director"}	2025-11-08 06:57:32.294319	2025-11-08 06:57:32.294319	bryansim10@yahoo.com	60162268998	bryan sim	\N
1594	6d550ccd-6d49-49e0-baf9-b398d62872bb	1	1	\N	Azizah Binti Abu Bakar	ezazizza@gmail.com	60138505973	t	2025-11-08 06:58:05.682155	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 06:58:05.682155	2025-11-08 06:58:05.682155	ezazizza@gmail.com	60138505973	azizah binti abu bakar	\N
1595	8f8aafaa-7f26-4f53-92af-38e4c8f0e7b2	1	1	\N	Sarah	dygnorsarah@gmail.com	60178327449	t	2025-11-08 06:58:15.08611	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 06:58:15.08611	2025-11-08 06:58:15.08611	dygnorsarah@gmail.com	60178327449	sarah	\N
1596	9520073b-6e15-461c-9a57-d17113f1940e	1	1	\N	Supiah Binti Yussof	supiahyussof1974@gmail.com	601127831534	t	2025-11-08 06:58:21.895055	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:58:21.895055	2025-11-08 06:58:21.895055	supiahyussof1974@gmail.com	601127831534	supiah binti yussof	\N
1597	c38c7bd2-d08c-4260-a36d-ae90824ee2f1	1	1	\N	Tracy	tracyks@hotmail.com	60168359739	t	2025-11-08 06:59:11.382149	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 06:59:11.382149	2025-11-08 06:59:11.382149	tracyks@hotmail.com	60168359739	tracy	\N
1599	36638d96-568f-47db-beab-0d58801fef7b	1	1	\N	Esmerelyndya Edward	esmerelyndya.edward@gmail.com	60195577314	t	2025-11-08 07:02:16.079379	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah Institute of Art ", "position": "Marketing and Business Development Manager "}	2025-11-08 07:02:16.079379	2025-11-08 07:02:16.079379	esmerelyndya.edward@gmail.com	60195577314	esmerelyndya edward	\N
1600	2b936962-4511-4a03-bf02-24eec00e0687	1	1	\N	Haniffah Binti Sugito	haniffah@audit.gov.my	60128035587	t	2025-11-08 07:02:31.849383	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "JABATAN AUDIT NEGARA NEGERI SABAH", "position": "PENOLONG JURUAUDIT"}	2025-11-08 07:02:31.849383	2025-11-08 07:02:31.849383	haniffah@audit.gov.my	60128035587	haniffah binti sugito	\N
1602	6fa274e6-c3dc-492f-9be7-41cec1971286	1	1	\N	Carl V Moosom	cmoosom@gmail.com	60128338337	t	2025-11-08 07:02:56.859285	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Kementerian Pembangunan Usahawan & Koperasi Malaysia", "position": "Setiausaha Politik"}	2025-11-08 07:02:56.859285	2025-11-08 07:02:56.859285	cmoosom@gmail.com	60128338337	carl v moosom	\N
1603	9fb3af31-364f-4171-885d-cc8f133ad95e	1	1	\N	Grace	Lovingcrazybee@gmail.com	6587515633	t	2025-11-08 07:03:15.31107	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No company ", "position": "No"}	2025-11-08 07:03:15.31107	2025-11-08 07:03:15.31107	lovingcrazybee@gmail.com	6587515633	grace	\N
1604	f994b069-3100-4945-ae3d-aa15d83c1eab	1	1	\N	Mohd Shayful Wasli	shayfulwasli@gmail.com	60168447321	t	2025-11-08 07:03:45.482536	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "LHDN", "position": "Executive Officer"}	2025-11-08 07:03:45.482536	2025-11-08 07:03:45.482536	shayfulwasli@gmail.com	60168447321	mohd shayful wasli	\N
1606	4a4a1617-4f02-4486-9f86-336c8c0a19fa	1	1	\N	Micheal Ting Chi An	mtm.miketing90@gmail.com	60168257303	t	2025-11-08 07:04:53.913911	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 07:04:53.913911	2025-11-08 07:04:53.913911	mtm.miketing90@gmail.com	60168257303	micheal ting chi an	\N
1607	8bbcffe0-9220-44a4-bf9f-327a0205ebad	1	1	\N	Ms Mei	Mei_que@yahoo.com	60138347511	t	2025-11-08 07:04:58.329953	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Rasi corporation", "position": "Acc"}	2025-11-08 07:04:58.329953	2025-11-08 07:04:58.329953	mei_que@yahoo.com	60138347511	ms mei	\N
1610	6bfb0636-3b93-41b9-8de6-589b1aeca6d7	1	1	\N	Ahmad Rizman	arizmanh0123@gmail.com	60178430860	t	2025-11-08 07:05:26.829908	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 07:05:26.829908	2025-11-08 07:05:26.829908	arizmanh0123@gmail.com	60178430860	ahmad rizman	\N
1611	1b47283c-229e-40fa-9246-044ec95d9341	1	1	\N	Alley	alley.atil@gmail.com	60178283930	t	2025-11-08 07:05:34.709908	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Firm Horizon ", "position": "Crew"}	2025-11-08 07:05:34.709908	2025-11-08 07:05:34.709908	alley.atil@gmail.com	60178283930	alley	\N
1612	45d61a9e-23dd-4576-abf2-44196018aa7d	1	1	\N	Charlieana Cyra	charlianacyra7@gmail.com	60178635371	t	2025-11-08 07:05:34.873614	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "fh", "position": "crew"}	2025-11-08 07:05:34.873614	2025-11-08 07:05:34.873614	charlianacyra7@gmail.com	60178635371	charlieana cyra	\N
1616	9a5682a3-ac64-43c1-a3df-01891754ad3b	1	1	\N	Miller Peter	millerpeter991@gmail.com	60138851799	t	2025-11-08 07:07:36.732908	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SAWIT KINABALU SDN BHD", "position": "-"}	2025-11-08 07:07:36.732908	2025-11-08 07:07:36.732908	millerpeter991@gmail.com	60138851799	miller peter	\N
1617	20b9a842-9806-44b4-92f6-64422bf8d58c	1	1	\N	Salmah Binti Mohamad	Ome_md@yahoo.com	60168493136	t	2025-11-08 07:08:06.002838	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "School", "position": "Teacher"}	2025-11-08 07:08:06.002838	2025-11-08 07:08:06.002838	ome_md@yahoo.com	60168493136	salmah binti mohamad	\N
1618	7a0a4111-c4ac-417e-a7ac-1439cdc7dae6	1	1	\N	Syahirah Izzatul Akmar	syierah.izzatul@gmail.com	60109405125	t	2025-11-08 07:08:17.751924	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Jabatan Bendahari Negeri", "position": "Pegawai Tadbir"}	2025-11-08 07:08:17.751924	2025-11-08 07:08:17.751924	syierah.izzatul@gmail.com	60109405125	syahirah izzatul akmar	\N
1619	8c344e57-f906-459b-ac3c-31cdf113e564	1	1	\N	Susilo	susilootomo@gmail.com	60168370262	t	2025-11-08 07:08:19.732819	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah Electricity", "position": "Technician"}	2025-11-08 07:08:19.732819	2025-11-08 07:08:19.732819	susilootomo@gmail.com	60168370262	susilo	\N
1620	b3bf9247-b0ad-458c-87a2-c5187146ce87	1	1	\N	Hwa Iing Nee	Knhwa@hotmail.com	60168101144	t	2025-11-08 07:08:33.560791	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Visitor", "position": "Visitor"}	2025-11-08 07:08:33.560791	2025-11-08 07:08:33.560791	knhwa@hotmail.com	60168101144	hwa iing nee	\N
1621	4e89f64c-9af4-4186-a7cb-9ffb0e8bbdd5	1	1	\N	Jennifer Ho	jennho83@gmail.com	60109320177	t	2025-11-08 07:08:38.687196	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "MY Management ", "position": "Sole Proprietor "}	2025-11-08 07:08:38.687196	2025-11-08 07:08:38.687196	jennho83@gmail.com	60109320177	jennifer ho	\N
1622	78958b45-8dd8-46e7-adb3-6e8a97466bda	1	1	\N	Jayson Stephen	Jayho1215@gmail.com	60149706590	t	2025-11-08 07:10:07.088458	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Jathers Group Sdn.Bhd", "position": "Director"}	2025-11-08 07:10:07.088458	2025-11-08 07:10:07.088458	jayho1215@gmail.com	60149706590	jayson stephen	\N
1623	fef203dc-2b3d-46a1-b9fe-c3d182d6e403	1	1	\N	Fun	NA@gmail.com	60138836968	t	2025-11-08 07:10:10.260421	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "'", "position": "H"}	2025-11-08 07:10:10.260421	2025-11-08 07:10:10.260421	na@gmail.com	60138836968	fun	\N
1624	81859321-dbe4-40dd-9c80-689023e3201a	1	1	\N	Theresia Timu Binti Petrus	Noonaanne90@gmail.com	60168351526	t	2025-11-08 07:10:23.222781	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Jathers group sdn bbhd", "position": "Finance"}	2025-11-08 07:10:23.222781	2025-11-08 07:10:23.222781	noonaanne90@gmail.com	60168351526	theresia timu binti petrus	\N
1625	1e5c108e-a18a-4b68-9cd3-09cfe68d9750	1	1	\N	Helen Soo	blsoo@hotmail.com	60168303385	t	2025-11-08 07:10:32.244244	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Visitor", "position": "Visitor"}	2025-11-08 07:10:32.244244	2025-11-08 07:10:32.244244	blsoo@hotmail.com	60168303385	helen soo	\N
1627	a463d9ff-1aef-45d1-a6de-97c6f597bbaf	1	1	\N	Hendrick David Augustine	Luntauanunbala@gmail.com	601163237311	t	2025-11-08 07:12:57.471615	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 07:12:57.471615	2025-11-08 07:12:57.471615	luntauanunbala@gmail.com	601163237311	hendrick david augustine	\N
1628	05621d64-b37f-43a9-ae3f-ab36ea9723f6	1	1	\N	Zain Azhar	zainaspire@yahoo.com	60128183228	t	2025-11-08 07:13:27.332084	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "EMAX Network Sdn Bhd", "position": "Marketing Manager"}	2025-11-08 07:13:27.332084	2025-11-08 07:13:27.332084	zainaspire@yahoo.com	60128183228	zain azhar	\N
1629	941d7ae6-69bb-42d9-8605-c420963f4c2f	1	1	\N	Johnnie	Johnnieting@hotmai.com	60198893311	t	2025-11-08 07:13:31.346592	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Alcabest ", "position": "Direcror "}	2025-11-08 07:13:31.346592	2025-11-08 07:13:31.346592	johnnieting@hotmai.com	60198893311	johnnie	\N
1631	6278fec5-8f26-4ba6-bd16-a888229d9d4d	1	1	\N	Fidelia Grace	gracefidelia@gmail.com	60165526564	t	2025-11-08 07:17:09.03179	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 07:17:09.03179	2025-11-08 07:17:09.03179	gracefidelia@gmail.com	60165526564	fidelia grace	\N
1632	d04fb353-2c0a-4ea7-905a-2d16f1669e21	1	1	\N	Janjelyn Joy	Jlyn8818@gmail.com	601172372198	t	2025-11-08 07:19:39.086266	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "Na"}	2025-11-08 07:19:39.086266	2025-11-08 07:19:39.086266	jlyn8818@gmail.com	601172372198	janjelyn joy	\N
1633	8b848a1f-137a-4f81-a4b1-ada1bda33977	1	1	\N	Fika	gadisishak23@gmail.com	60175168664	t	2025-11-08 07:21:24.942796	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "NA"}	2025-11-08 07:21:24.942796	2025-11-08 07:21:24.942796	gadisishak23@gmail.com	60175168664	fika	\N
1634	9674f34d-9e1a-4619-a6c6-77a2358ecf44	1	1	\N	Mohd Azreen Bin Abdul Ajis	maestro.ingenious@gmail.com	60168314141	t	2025-11-08 07:26:47.343883	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Etiqa Family Takaful Berhad", "position": "Agency Director"}	2025-11-08 07:26:47.343883	2025-11-08 07:26:47.343883	maestro.ingenious@gmail.com	60168314141	mohd azreen bin abdul ajis	\N
1635	e8a7700e-b651-4f18-80a9-b89ab182f123	1	1	\N	Sanlin Ludin	Mcy_lin@yahoo.co.nz	60166710513	t	2025-11-08 07:28:29.623637	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "na"}	2025-11-08 07:28:29.623637	2025-11-08 07:28:29.623637	mcy_lin@yahoo.co.nz	60166710513	sanlin ludin	\N
1637	e8a31a3a-a992-4e65-be42-98ee7144d581	1	1	\N	Annie Chong	anniechong75@hotmail.com	601126109313	t	2025-11-08 07:28:46.890284	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "no", "position": "no"}	2025-11-08 07:28:46.890284	2025-11-08 07:28:46.890284	anniechong75@hotmail.com	601126109313	annie chong	\N
1638	d651b5de-dcd5-445e-9d3d-69bd2db6da27	1	1	\N	Anna Inna Affirna	annainna111@gmail.com	60198971475	t	2025-11-08 07:29:07.843949	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "GNT TRAVEL & TOURS SDN BHD", "position": "OPERATION MANAGER"}	2025-11-08 07:29:07.843949	2025-11-08 07:29:07.843949	annainna111@gmail.com	60198971475	anna inna affirna	\N
1639	0a6fcc46-c02f-4064-9987-f21098e59c1f	1	1	\N	Annie	annieshin888@yahoo.com.my	60149318278	t	2025-11-08 07:29:58.16663	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Chillie boy", "position": "Manager"}	2025-11-08 07:29:58.16663	2025-11-08 07:29:58.16663	annieshin888@yahoo.com.my	60149318278	annie	\N
1640	532187a6-9f3b-4918-bb77-6325fb41e6ed	1	1	\N	Qh	abrienda88@gmail.con	60164883270	t	2025-11-08 07:31:38.235103	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 07:31:38.235103	2025-11-08 07:31:38.235103	abrienda88@gmail.con	60164883270	qh	\N
1642	41f45d1f-e824-4deb-834a-89a6631e6a25	1	1	\N	Teh Xiao Xuan	tehxiaoxuan@gmail.com	601131291796	t	2025-11-08 07:31:55.10738	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NIL", "position": "NIL"}	2025-11-08 07:31:55.10738	2025-11-08 07:31:55.10738	tehxiaoxuan@gmail.com	601131291796	teh xiao xuan	\N
1645	35e10fdc-7866-4823-828a-56224593e0a7	1	1	\N	Wong Fui Yee	Sandrawong84@gmail.com	60134913051	t	2025-11-08 07:34:21.220616	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Golden Spring Gourmet ", "position": "Director"}	2025-11-08 07:34:21.220616	2025-11-08 07:34:21.220616	sandrawong84@gmail.com	60134913051	wong fui yee	\N
1646	6c9940c5-bccd-491d-9a67-9f524c8a6345	1	1	\N	Stonny Sheh	vuisheh@gmail.com	601151549513	t	2025-11-08 07:34:28.772837	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Golden spring gourmet", "position": "Director "}	2025-11-08 07:34:28.772837	2025-11-08 07:34:28.772837	vuisheh@gmail.com	601151549513	stonny sheh	\N
1648	8c0b3919-1414-4632-8e69-b989f7b486b3	1	1	\N	Bernadinarono	bernadinaronoantonius@gmail.com	60168028924	t	2025-11-08 07:47:19.109688	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 07:47:19.109688	2025-11-08 07:47:19.109688	bernadinaronoantonius@gmail.com	60168028924	bernadinarono	\N
1647	6d612233-da9a-4747-ba76-c758b94b3712	1	1	\N	Ho Fui Lu	fuiluho@gmail.com	60106528686	t	2025-11-08 07:41:18.41407	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-08 07:41:18.41407	2025-11-08 07:41:18.41407	fuiluho@gmail.com	60106528686	ho fui lu	\N
1649	c166ac89-82c2-4aca-8c70-f697ebe74322	1	1	\N	Sharone	sharonechung@yahoo.com	60178999089	t	2025-11-08 07:48:45.667051	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 07:48:45.667051	2025-11-08 07:48:45.667051	sharonechung@yahoo.com	60178999089	sharone	\N
1650	e9821347-e8f2-4db2-8646-bca92e6d9222	1	1	\N	Lim Ling Hui	lmargretha@yahoo.com	60197798686	t	2025-11-08 07:49:37.242499	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 07:49:37.242499	2025-11-08 07:49:37.242499	lmargretha@yahoo.com	60197798686	lim ling hui	\N
1651	41007a99-678c-4d5c-969d-119d6009fdb1	1	1	\N	Liewkenshyong	Edwardliew368@gmail.com	60168449539	t	2025-11-08 07:51:33.606498	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 07:51:33.606498	2025-11-08 07:51:33.606498	edwardliew368@gmail.com	60168449539	liewkenshyong	\N
1652	ae53b4f1-6a37-4243-bb5d-481ef0e9ae77	1	1	\N	Chang Woei Ying	woeiying_chang@yahoo.com.my	601131981938	t	2025-11-08 07:52:15.685584	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Unemployed", "position": "-"}	2025-11-08 07:52:15.685584	2025-11-08 07:52:15.685584	woeiying_chang@yahoo.com.my	601131981938	chang woei ying	\N
1653	925735ec-b06c-4db1-8940-746472644987	1	1	\N	Doria	Dorishoo78@gmail.com	601162843931	t	2025-11-08 07:52:25.180086	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 07:52:25.180086	2025-11-08 07:52:25.180086	dorishoo78@gmail.com	601162843931	doria	\N
1654	3a8417ee-af98-40a8-b7dd-db39e0ff8b22	1	1	\N	Junior Xavier Jipinol	jraynerwenn@gmail.com	60134801834	t	2025-11-08 07:55:29.412296	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah Port ", "position": "Container Declarer"}	2025-11-08 07:55:29.412296	2025-11-08 07:55:29.412296	jraynerwenn@gmail.com	60134801834	junior xavier jipinol	\N
1655	76dd5f6d-9a67-4edd-ab82-bea4092247a6	1	1	\N	Winnie Kan	Winnie_ktc06@yahoo.com	60168195939	t	2025-11-08 07:56:23.62058	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Harrisons Sabah Sdn bhd", "position": "Account "}	2025-11-08 07:56:23.62058	2025-11-08 07:56:23.62058	winnie_ktc06@yahoo.com	60168195939	winnie kan	\N
1658	296de9b9-350d-4b74-81dd-6ad0f153ed47	1	1	\N	Ethan	Ethanlim@gmail.com	60168227608	t	2025-11-08 08:01:06.017161	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "kLM construction sdn.bhd", "position": "Manager "}	2025-11-08 08:01:06.017161	2025-11-08 08:01:06.017161	ethanlim@gmail.com	60168227608	ethan	\N
1661	c109903c-b4a5-41da-88eb-5c74f72869df	1	1	\N	Owen	acomeyowen13@gmail.com	60124120782	t	2025-11-08 08:02:40.983428	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SKYAPCONSULTING SDN BHD", "position": "Accountant"}	2025-11-08 08:02:40.983428	2025-11-08 08:02:40.983428	acomeyowen13@gmail.com	60124120782	owen	\N
1662	da543133-d48f-44ed-96ea-fe26a2605d00	1	1	\N	Aling	wongsengling@yahoo.com	60109472050	t	2025-11-08 08:02:53.240998	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "FV & J Partner", "position": "Account assisstant"}	2025-11-08 08:02:53.240998	2025-11-08 08:02:53.240998	wongsengling@yahoo.com	60109472050	aling	\N
1664	21fd476b-c4ee-41e9-83f6-704199d9c452	1	1	\N	Ng Lay Eng	irenenglayeng@gmail.com	60168338369	t	2025-11-08 08:07:56.226594	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabastamping Enterprise ", "position": "Manager"}	2025-11-08 08:07:56.226594	2025-11-08 08:07:56.226594	irenenglayeng@gmail.com	60168338369	ng lay eng	\N
1666	4ec1606b-0577-450a-9b8b-4aa1cc4de394	1	1	\N	Wong Chiue Yee	fanniewong76@gmail.com	60109313008	t	2025-11-08 08:09:49.674976	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:09:49.674976	2025-11-08 08:09:49.674976	fanniewong76@gmail.com	60109313008	wong chiue yee	\N
1667	48cb808d-41a5-4f3c-aa01-a2d3a037c327	1	1	\N	David Kong	davidkong_71@yahoo.com	60198208830	t	2025-11-08 08:10:14.646183	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:10:14.646183	2025-11-08 08:10:14.646183	davidkong_71@yahoo.com	60198208830	david kong	\N
1669	5cb7578c-3c11-4d3c-badd-2e7e5a3ffef2	1	1	\N	Mohd Azleesham	mohdazleesham98@gmail.com	601162176197	t	2025-11-08 08:10:54.612052	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:10:54.612052	2025-11-08 08:10:54.612052	mohdazleesham98@gmail.com	601162176197	mohd azleesham	\N
1670	a213a3bc-3852-4a78-ac90-c2676af58664	1	1	\N	Walter Ng	walterng1845@gmail.com	60163686918	t	2025-11-08 08:11:30.457858	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Saba stamping Enterprises ", "position": "Executive "}	2025-11-08 08:11:30.457858	2025-11-08 08:11:30.457858	walterng1845@gmail.com	60163686918	walter ng	\N
1671	85093da6-1b0a-4a6c-870b-5321a14275b3	1	1	\N	Albert Wong	wongalbert138@yahoo.com	60128300768	t	2025-11-08 08:11:45.027189	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:11:45.027189	2025-11-08 08:11:45.027189	wongalbert138@yahoo.com	60128300768	albert wong	\N
1672	26e5a02c-05dc-4749-804a-a62b841e63a5	1	1	\N	Winnie	winnievoo63@gmail.com	60168284189	t	2025-11-08 08:12:33.648508	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:12:33.648508	2025-11-08 08:12:33.648508	winnievoo63@gmail.com	60168284189	winnie	\N
1673	c6c0d010-7ec6-4381-8d14-e35649c628be	1	1	\N	Florisa	cuteyomiko@gmail.com	60143560173	t	2025-11-08 08:12:35.661042	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:12:35.661042	2025-11-08 08:12:35.661042	cuteyomiko@gmail.com	60143560173	florisa	\N
1674	46e2d3ee-b7ec-482a-b63d-8b3502b8aaee	1	1	\N	Alcelyn	Lingrose1234@gmail.com	601112149699	t	2025-11-08 08:14:27.083805	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "CS Enterprise", "position": "Director "}	2025-11-08 08:14:27.083805	2025-11-08 08:14:27.083805	lingrose1234@gmail.com	601112149699	alcelyn	\N
1675	6c75c7d2-e302-4207-9085-6f3fa339de77	1	1	\N	Felicia	nekolim1993@gmail.com	60168793955	t	2025-11-08 08:14:54.845584	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 08:14:54.845584	2025-11-08 08:14:54.845584	nekolim1993@gmail.com	60168793955	felicia	\N
1676	5023baf7-ebc1-45ee-87f9-ec7d37d3bbfa	1	1	\N	Noraini Binti Kamis	aieyndchp_86@yahoo.com	60146752326	t	2025-11-08 08:15:53.179186	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 08:15:53.179186	2025-11-08 08:15:53.179186	aieyndchp_86@yahoo.com	60146752326	noraini binti kamis	\N
1677	670298c0-d984-4405-9c95-74ece68baa54	1	1	\N	Norianie Kamis	aineycullen@gmail.com	601116442106	t	2025-11-08 08:15:56.459605	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 08:15:56.459605	2025-11-08 08:15:56.459605	aineycullen@gmail.com	601116442106	norianie kamis	\N
1678	1f3fc408-2be8-4c97-92b3-4c58d3011d7d	1	1	\N	Andrea Audrey Mahadin	andreaaudrey021205@gmail.com	60166917068	t	2025-11-08 08:18:13.489396	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Non", "position": "Na"}	2025-11-08 08:18:13.489396	2025-11-08 08:18:13.489396	andreaaudrey021205@gmail.com	60166917068	andrea audrey mahadin	\N
1679	73d2d659-986e-4f91-8a28-f26e8a083385	1	1	\N	Naziyan Jilit	nazianjilit@gmail.com	60195331414	t	2025-11-08 08:21:12.365839	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "menta  contruction sdn bhd", "position": "qs"}	2025-11-08 08:21:12.365839	2025-11-08 08:21:12.365839	nazianjilit@gmail.com	60195331414	naziyan jilit	\N
1681	9a343d02-1818-4016-86c2-20f63c058a57	1	1	\N	Albert	hods.kk@gmail.com	60133878003	t	2025-11-08 08:22:14.625637	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "House of Dresses ", "position": "Manager "}	2025-11-08 08:22:14.625637	2025-11-08 08:22:14.625637	hods.kk@gmail.com	60133878003	albert	\N
1682	fe089e18-da41-4e54-88b5-98c914ea6e8d	1	1	\N	Evonne Hanis	Evonnehanis@gmail.com	601116831004	t	2025-11-08 08:24:21.923344	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:24:21.923344	2025-11-08 08:24:21.923344	evonnehanis@gmail.com	601116831004	evonne hanis	\N
1683	b78ed1af-ae25-42ed-9653-6f27854c01f5	1	1	\N	Sandralela	Sandra_ayie@yahoo.com	601131525503	t	2025-11-08 08:33:32.695949	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-08 08:33:32.695949	2025-11-08 08:33:32.695949	sandra_ayie@yahoo.com	601131525503	sandralela	\N
1685	6c169c95-ca7c-4fa7-ad8d-cb6f31eebe95	1	1	\N	Mohd Sayzmie Bin Kassim	sayzmiefx@gmail.com	601136934069	t	2025-11-08 08:35:20.909869	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ziyad Network", "position": "Manager"}	2025-11-08 08:35:20.909869	2025-11-08 08:35:20.909869	sayzmiefx@gmail.com	601136934069	mohd sayzmie bin kassim	\N
1687	94b925df-e306-47e8-9995-7cfdb636c678	1	1	\N	Angeline	Kimisoisabah@gmail.com	60168343168	t	2025-11-08 08:36:11.0611	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Mind Miner Acqdemy", "position": "Manager"}	2025-11-08 08:36:11.0611	2025-11-08 08:36:11.0611	kimisoisabah@gmail.com	60168343168	angeline	\N
1689	e87d06ad-a342-4eed-84a3-b79ea4f0dcd4	1	1	\N	Voo Nyet Fah	shirlyvoo@yahoo.com	60138518883	t	2025-11-08 08:39:16.648093	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 08:39:16.648093	2025-11-08 08:39:16.648093	shirlyvoo@yahoo.com	60138518883	voo nyet fah	\N
1690	537a8d36-f4bf-4df8-acb8-377fc79cd652	1	1	\N	Seow	seowsoonhuat@gmail.com	60168308881	t	2025-11-08 08:39:50.281706	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "N/A", "position": "N/A"}	2025-11-08 08:39:50.281706	2025-11-08 08:39:50.281706	seowsoonhuat@gmail.com	60168308881	seow	\N
1692	62a615aa-49ff-49c0-9d7b-a171f73202fc	1	1	\N	Grace Wong	gracegrace6789@gmail.com	60138384857	t	2025-11-08 08:40:48.071089	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "brilliant trading & supplies sdn bhd", "position": "Assistant manager"}	2025-11-08 08:40:48.071089	2025-11-08 08:40:48.071089	gracegrace6789@gmail.com	60138384857	grace wong	\N
1694	e1c18ab4-f157-4602-ac33-e5b9c885cf9e	1	1	\N	Nazurah Binti Mohamd	nazurah_210289@yahoo.com.my	60138600950	t	2025-11-08 08:45:23.848021	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 08:45:23.848021	2025-11-08 08:45:23.848021	nazurah_210289@yahoo.com.my	60138600950	nazurah binti mohamd	\N
1697	7e3fd8de-360c-4b1d-aed3-7d69af6ed6c6	1	1	\N	Juslan	juslanibrahim@gmail.com	60163608807	t	2025-11-08 08:48:22.036617	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 08:48:22.036617	2025-11-08 08:48:22.036617	juslanibrahim@gmail.com	60163608807	juslan	\N
1699	3cea1404-390a-402d-9156-596b98d2d3a1	1	1	\N	Seseorang	saku5887@gmail.com	601153801811	t	2025-11-08 08:49:50.166015	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "UMS", "position": "Lecturer"}	2025-11-08 08:49:50.166015	2025-11-08 08:49:50.166015	saku5887@gmail.com	601153801811	seseorang	\N
1700	3ba433c2-f1d5-4cc8-bd88-30054cb3bb23	1	1	\N	Mohamad Idham Bin Mohzir	Idhambmohzir@gmail.com	601127270868	t	2025-11-08 08:51:42.495959	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "TLDM ", "position": "Engineer "}	2025-11-08 08:51:42.495959	2025-11-08 08:51:42.495959	idhambmohzir@gmail.com	601127270868	mohamad idham bin mohzir	\N
1701	49b8e4ad-df8c-49fb-9b4b-b05f8eb6383c	1	1	\N	Max Borinus	marxmillans@gmail.com	601114151700	t	2025-11-08 08:54:01.319436	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "PDB", "position": "Sales"}	2025-11-08 08:54:01.319436	2025-11-08 08:54:01.319436	marxmillans@gmail.com	601114151700	max borinus	\N
1702	ffe51d39-c01a-4ab4-a838-b4cd85602b75	1	1	\N	Norsyazana Binti Abdul Rahim	Norsyazanaabdulrahim@gmail.com	60105309294	t	2025-11-08 08:56:27.943225	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 08:56:27.943225	2025-11-08 08:56:27.943225	norsyazanaabdulrahim@gmail.com	60105309294	norsyazana binti abdul rahim	\N
1703	1f3b019a-34ea-4df2-b07f-90476284201c	1	1	\N	Fairuz	fas_1710@yahoo.com	60168229509	t	2025-11-08 09:00:53.598895	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 09:00:53.598895	2025-11-08 09:00:53.598895	fas_1710@yahoo.com	60168229509	fairuz	\N
1704	bc077368-563d-4b99-9be9-11689d5b446d	1	1	\N	Asmah	asmaharum77@gmail.com	60198316512	t	2025-11-08 09:01:01.405807	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 09:01:01.405807	2025-11-08 09:01:01.405807	asmaharum77@gmail.com	60198316512	asmah	\N
1705	a3e5fb80-5f7f-49be-81c0-c1c275e325ae	1	1	\N	Dayang Nur Azwani Binti Azaman	dayangnurazwani96@gmail.com	60149516088	t	2025-11-08 09:01:08.793636	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-08 09:01:08.793636	2025-11-08 09:01:08.793636	dayangnurazwani96@gmail.com	60149516088	dayang nur azwani binti azaman	\N
1706	865f4c15-2470-4367-8f58-21748dd4ffb7	1	1	\N	Ng Lee Kuan	catherinevv1115@gmail.com	60178608886	t	2025-11-08 09:03:14.281556	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 09:03:14.281556	2025-11-08 09:03:14.281556	catherinevv1115@gmail.com	60178608886	ng lee kuan	\N
1707	ae13774b-f86a-4d58-8188-a97f851fbd95	1	1	\N	Hisham Bin Hasan	jaja.cpg@gmail.com	60136802911	t	2025-11-08 09:06:55.287543	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ADTEC JTM Kampus Kota Kinabalu", "position": "Lecturer"}	2025-11-08 09:06:55.287543	2025-11-08 09:06:55.287543	jaja.cpg@gmail.com	60136802911	hisham bin hasan	\N
1708	0f88e790-b822-475a-a9c8-f2fa89ffac04	1	1	\N	Faezza Binti Ismail	shamjskk@gmail.com	60148856508	t	2025-11-08 09:15:41.954937	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Politeknik kota Kinabalu", "position": "Lecturer"}	2025-11-08 09:15:41.954937	2025-11-08 09:15:41.954937	shamjskk@gmail.com	60148856508	faezza binti ismail	\N
1709	bf834ad5-8289-4fdd-ac8e-42767dce869a	1	1	\N	Siti Nooraini Binti Rashid	nyeling@gmail.com	60102553575	t	2025-11-08 09:16:57.795962	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-08 09:16:57.795962	2025-11-08 09:16:57.795962	nyeling@gmail.com	60102553575	siti nooraini binti rashid	\N
1710	01447325-c3bf-43d5-8cdd-4ad7f8de8939	1	1	\N	Vanessa	Vanz.9091@gmail.com	60168194264	t	2025-11-08 09:26:06.425717	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Brego", "position": "Exec"}	2025-11-08 09:26:06.425717	2025-11-08 09:26:06.425717	vanz.9091@gmail.com	60168194264	vanessa	\N
1711	501722b2-4635-4276-8fdc-4052ba0c0a11	1	1	\N	Faye Wong	fayewong96@outlook.com	60109377345	t	2025-11-08 09:26:43.558672	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ALLIANCE BANK BERHAD", "position": "EXECUTIVE"}	2025-11-08 09:26:43.558672	2025-11-08 09:26:43.558672	fayewong96@outlook.com	60109377345	faye wong	\N
1714	0c3a7bd9-aab4-480a-81de-ddbcba0b06ee	1	1	\N	Joy	joyearainjoy@gmail.com	60163747477	t	2025-11-09 01:00:16.680961	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Student", "position": "No"}	2025-11-09 01:00:16.680961	2025-11-09 01:00:16.680961	joyearainjoy@gmail.com	60163747477	joy	\N
1715	ea543433-9cde-4644-b662-16d0e939e0bd	1	1	\N	Selvi	cselviwalter@gmail.com	601151259622	t	2025-11-09 01:02:30.520426	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Baker Tilly", "position": "Crew"}	2025-11-09 01:02:30.520426	2025-11-09 01:02:30.520426	cselviwalter@gmail.com	601151259622	selvi	\N
1716	2c8ca2ed-460c-4c2a-939c-6ab4cd8ddf14	1	1	\N	Nur Syaherah Binti Sinun	Nursyherah@gmail.com	60135398661	t	2025-11-09 01:08:31.450573	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Student", "position": "Visitor"}	2025-11-09 01:08:31.450573	2025-11-09 01:08:31.450573	nursyherah@gmail.com	60135398661	nur syaherah binti sinun	\N
1717	66923ec4-01e2-45d3-9405-5c502cd39c0c	1	1	\N	Esther Lim	Kharyee84@gmail.com	60168800332	t	2025-11-09 01:46:43.276395	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Limamaju", "position": "Owner"}	2025-11-09 01:46:43.276395	2025-11-09 01:46:43.276395	kharyee84@gmail.com	60168800332	esther lim	\N
1733	17a3a63b-7ed9-453c-86ef-13a1bf109d14	1	1	\N	Muhammad Nur Iqmal Bin Hermanto	iqmal0607@gmail.com	601116570706	t	2025-11-09 02:47:00.183494	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "no", "position": "no"}	2025-11-09 02:47:00.183494	2025-11-09 02:47:00.183494	iqmal0607@gmail.com	601116570706	muhammad nur iqmal bin hermanto	\N
1734	c8ba646e-100e-4f70-83b8-0fb7595a0e23	1	1	\N	Matthew Chiang Chung Wai	matthewchiang1986@gmail.com	60168292717	t	2025-11-09 02:51:21.442955	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "15 minutes bake", "position": "Coffee trainer"}	2025-11-09 02:51:21.442955	2025-11-09 02:51:21.442955	matthewchiang1986@gmail.com	60168292717	matthew chiang chung wai	\N
1735	19e710b9-c4a3-4b20-a865-e73d7b7688cd	1	1	\N	Eileen Liew	emyliew@yahoo.com	60168467799	t	2025-11-09 02:51:29.217212	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NF"}	2025-11-09 02:51:29.217212	2025-11-09 02:51:29.217212	emyliew@yahoo.com	60168467799	eileen liew	\N
1736	d2f0e286-c351-46e0-80e3-c0e13501943e	1	1	\N	Lo Pui Fong	yvonnelo1227@gmail.com	60138561668	t	2025-11-09 02:52:27.267771	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SG Trading SB", "position": "Director"}	2025-11-09 02:52:27.267771	2025-11-09 02:52:27.267771	yvonnelo1227@gmail.com	60138561668	lo pui fong	\N
1737	82bef22f-da0c-4738-91d1-64ce3d8c784b	1	1	\N	Allenchia	allenchi_891011@icloud.com	60168107499	t	2025-11-09 02:54:40.512225	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Pusat Pintu Putatan", "position": "Sales man"}	2025-11-09 02:54:40.512225	2025-11-09 02:54:40.512225	allenchi_891011@icloud.com	60168107499	allenchia	\N
1738	89be7d61-4ed9-4949-898c-ed3fe36914f2	1	1	\N	Erlissoniayanti	Erly89yan@gmail.com	60165878901	t	2025-11-09 02:55:10.353132	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Pusat pintu putatan", "position": "Salesgirl"}	2025-11-09 02:55:10.353132	2025-11-09 02:55:10.353132	erly89yan@gmail.com	60165878901	erlissoniayanti	\N
1739	ce3260ac-4a0d-47d4-81d6-5f1598862783	1	1	\N	Rex Yap	Yky191@gmail.com	60178669312	t	2025-11-09 02:55:33.415667	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 02:55:33.415667	2025-11-09 02:55:33.415667	yky191@gmail.com	60178669312	rex yap	\N
1740	15ac89c2-4f44-4e02-b2b6-f98289ea6d02	1	1	\N	Lucy Binti Thomas	cysharon1984@gmail.com	60138522811	t	2025-11-09 02:55:54.851919	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "CY LEGACY ", "position": "Sales "}	2025-11-09 02:55:54.851919	2025-11-09 02:55:54.851919	cysharon1984@gmail.com	60138522811	lucy binti thomas	\N
1743	0873e1b8-7488-48e0-9204-4129d62cc2ff	1	1	\N	Muhamad Khalilhilmi Bin Kamsim	khalilh442@gmail.com	60138300204	t	2025-11-09 03:23:21.400528	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 03:23:21.400528	2025-11-09 03:23:21.400528	khalilh442@gmail.com	60138300204	muhamad khalilhilmi bin kamsim	\N
1752	e5cec92e-588a-442d-9e7b-1b9c322f312b	1	1	\N	Joshua Yared	joshuayared@gmail.com	60178137649	t	2025-11-09 03:50:14.553845	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Impact zone sdn bhd", "position": "Designer"}	2025-11-09 03:50:14.553845	2025-11-09 03:50:14.553845	joshuayared@gmail.com	60178137649	joshua yared	\N
1753	5367d793-4cd8-4659-ac13-224b237493ff	1	1	\N	Meachellyndra Ann	Mic.yndra@gmail.com	601114107748	t	2025-11-09 03:50:15.032984	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Pawi borneo nature sdn bhd", "position": "Admin"}	2025-11-09 03:50:15.032984	2025-11-09 03:50:15.032984	mic.yndra@gmail.com	601114107748	meachellyndra ann	\N
1754	b4b799a2-f70f-4f89-8ae2-aaf576a81ce8	1	1	\N	Then Tze Ya	danielaine7776@yahoo.com	60138704619	t	2025-11-09 03:50:40.342666	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Utama Jurutera Perunding ", "position": "Draft Woman "}	2025-11-09 03:50:40.342666	2025-11-09 03:50:40.342666	danielaine7776@yahoo.com	60138704619	then tze ya	\N
1755	543e512f-3a52-46d7-915a-590c3b5b8990	1	1	\N	Chea Jsun Yun	danielaine7776@yahoo.com	60168332870	t	2025-11-09 03:50:56.665226	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Axtrada (m) sdn bhd", "position": "Technical support manager"}	2025-11-09 03:50:56.665226	2025-11-09 03:50:56.665226	danielaine7776@yahoo.com	60168332870	chea jsun yun	\N
1756	8db1e012-c1aa-488d-b23a-f713bcde0c1b	1	1	\N	Esther	chungpingyien@yahoo.com	60178111699	t	2025-11-09 03:54:22.722592	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Py trading", "position": "Manager "}	2025-11-09 03:54:22.722592	2025-11-09 03:54:22.722592	chungpingyien@yahoo.com	60178111699	esther	\N
1763	0f7e8aef-d738-4e2d-88ca-28217c4446e5	1	1	\N	John Dinh	John@goldensunriseseniorlife.com	84962345354	t	2025-11-09 03:55:51.443366	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Golden Sunrise", "position": "Business Development Partner"}	2025-11-09 03:55:51.443366	2025-11-09 03:55:51.443366	john@goldensunriseseniorlife.com	84962345354	john dinh	\N
1764	d572d400-e878-4563-b8ce-26889e47a40f	1	1	\N	Rosnani Binti Sidin	rizq74@yahoo.com.my	60138844936	t	2025-11-09 03:56:59.069576	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SMKA TUN AHMADSHAH", "position": "Pengetua"}	2025-11-09 03:56:59.069576	2025-11-09 03:56:59.069576	rizq74@yahoo.com.my	60138844936	rosnani binti sidin	\N
1765	74d9e0df-bbc8-404b-b84c-6941f141e889	1	1	\N	Zuraidah Binti Hamdin	zuraidahhamdin@yahoo.com.mu	60178172728	t	2025-11-09 03:57:01.447708	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SMA AL-IRSYADIAH RANAU", "position": "PRINCIPAL"}	2025-11-09 03:57:01.447708	2025-11-09 03:57:01.447708	zuraidahhamdin@yahoo.com.mu	60178172728	zuraidah binti hamdin	\N
1766	6aa2dcd2-0979-4234-8e37-53f2aa511326	1	1	\N	Mohd Yusri Bin Omar	yuslee4487@gmail.com	60169717876	t	2025-11-09 03:58:18.554437	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 03:58:18.554437	2025-11-09 03:58:18.554437	yuslee4487@gmail.com	60169717876	mohd yusri bin omar	\N
1767	a526c98b-5127-4490-8a63-43c54dc9a20a	1	1	\N	Seek King Whoo	kwhoo_93@hotmail.com	60168101673	t	2025-11-09 03:59:10.742505	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "My preztels sabah sdn bhd", "position": "Manager"}	2025-11-09 03:59:10.742505	2025-11-09 03:59:10.742505	kwhoo_93@hotmail.com	60168101673	seek king whoo	\N
1770	b234bdd0-b950-43a5-944b-16e3149155a6	1	1	\N	Marida Angkie	mandaangkie2811@gmail.com	60146539151	t	2025-11-09 04:03:40.66503	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": ",", "position": ","}	2025-11-09 04:03:40.66503	2025-11-09 04:03:40.66503	mandaangkie2811@gmail.com	60146539151	marida angkie	\N
1771	16046165-a0b5-4321-b196-1bb7c329b033	1	1	\N	Jamilah Jamri	Melhaikal8@gmail.com	601111713002	t	2025-11-09 04:03:49.355127	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": ", ", "position": ", "}	2025-11-09 04:03:49.355127	2025-11-09 04:03:49.355127	melhaikal8@gmail.com	601111713002	jamilah jamri	\N
1774	7af517fe-17bf-44b9-ab32-584453f72fea	1	1	\N	Edwin Pang	zixintan120@gmail.com	60192952840	t	2025-11-09 04:05:55.324271	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Classic Curtain", "position": "CEO"}	2025-11-09 04:05:55.324271	2025-11-09 04:05:55.324271	zixintan120@gmail.com	60192952840	edwin pang	\N
1775	c82919d3-c6a2-4f37-ae78-93a55f8bfaba	1	1	\N	Junaidah Justin Jaibun	130113jun@gmail.com	601155976939	t	2025-11-09 04:06:09.184101	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:06:09.184101	2025-11-09 04:06:09.184101	130113jun@gmail.com	601155976939	junaidah justin jaibun	\N
1780	d610037e-3d2f-4cd5-8dcd-63faf314176e	1	1	\N	Shaffiq	rezqenterprose@gmail.com	60149524341	t	2025-11-09 04:06:48.690757	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "REZQ ENTERPRISE", "position": "Owner"}	2025-11-09 04:06:48.690757	2025-11-09 04:06:48.690757	rezqenterprose@gmail.com	60149524341	shaffiq	\N
1784	911fe2e3-6a61-4d7a-a031-08c6dd156d76	1	1	\N	Syarinah	syarynmohd@gmail.com	60194017196	t	2025-11-09 04:07:18.759422	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:07:18.759422	2025-11-09 04:07:18.759422	syarynmohd@gmail.com	60194017196	syarinah	\N
1785	944a8bbb-e5c1-4c4b-96f9-9573b72ed11b	1	1	\N	Nur Adibah Binti Ibrahim	adibah.prsn@gmail.com	60165826920	t	2025-11-09 04:07:30.337557	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NADI", "position": "Manager"}	2025-11-09 04:07:30.337557	2025-11-09 04:07:30.337557	adibah.prsn@gmail.com	60165826920	nur adibah binti ibrahim	\N
1792	aad56a2a-a53a-4593-85ba-6ffdbb3344ad	1	1	\N	Afina Kinambura Binti Mazlan	manager@kampung-warisan.nadi.my	60198702781	t	2025-11-09 04:10:37.729714	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:10:37.729714	2025-11-09 04:10:37.729714	manager@kampung-warisan.nadi.my	60198702781	afina kinambura binti mazlan	\N
1793	d2e7d42f-4deb-4af4-bea3-7ceca88937f4	1	1	\N	Edwin	edwinpang13@gmail.com	60167184048	t	2025-11-09 04:10:50.454813	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Classic curtain", "position": "Partner"}	2025-11-09 04:10:50.454813	2025-11-09 04:10:50.454813	edwinpang13@gmail.com	60167184048	edwin	\N
1794	be0cc15b-614a-41ad-84e9-5242307f9e23	1	1	\N	Erma Hani Binti Baharudzaman	ermahanibaharudzaman@yahoo.com	601126861412	t	2025-11-09 04:10:56.378726	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:10:56.378726	2025-11-09 04:10:56.378726	ermahanibaharudzaman@yahoo.com	601126861412	erma hani binti baharudzaman	\N
1795	ae3f5010-4c06-46a8-95c0-69a79982c3d4	1	1	\N	Siti Hazwani Binit Yaakub	wanisiti7@gmail.com	60143559613	t	2025-11-09 04:11:05.414344	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:11:05.414344	2025-11-09 04:11:05.414344	wanisiti7@gmail.com	60143559613	siti hazwani binit yaakub	\N
1796	81d2c82f-1a69-4823-8894-2716d0a046f2	1	1	\N	Mazmin Binti Ag Matusin	mazmin207@gmail.com	60138711784	t	2025-11-09 04:11:27.34296	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:11:27.34296	2025-11-09 04:11:27.34296	mazmin207@gmail.com	60138711784	mazmin binti ag matusin	\N
1797	89db7fb7-86ea-4d78-af8e-235b37174b22	1	1	\N	Linb	trinhhanhlinh2000@yahoo.com	60168461487	t	2025-11-09 04:13:02.900838	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "_"}	2025-11-09 04:13:02.900838	2025-11-09 04:13:02.900838	trinhhanhlinh2000@yahoo.com	60168461487	linb	\N
1798	8ea8ca99-475b-45ca-a1b2-713495dbcf5f	1	1	\N	Sikinzai	syikin1802@yahoo.com	60138995510	t	2025-11-09 04:13:12.807026	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:13:12.807026	2025-11-09 04:13:12.807026	syikin1802@yahoo.com	60138995510	sikinzai	\N
1799	f9e4774d-91be-4451-96e5-8e37665733f0	1	1	\N	Jeremy Tong	jeremytongwc@gmail.com	60169965487	t	2025-11-09 04:13:42.713336	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Xx", "position": "Xx"}	2025-11-09 04:13:42.713336	2025-11-09 04:13:42.713336	jeremytongwc@gmail.com	60169965487	jeremy tong	\N
1800	5fbf43b6-f92a-4098-a59e-acacebd4c061	1	1	\N	Justin	Ray_work007@hotmail.com	60168294984	t	2025-11-09 04:14:01.810606	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "A", "position": "A"}	2025-11-09 04:14:01.810606	2025-11-09 04:14:01.810606	ray_work007@hotmail.com	60168294984	justin	\N
1803	bb4e46a8-2dc5-4682-ac4d-0aa7f7e87313	1	1	\N	Jane Evytha Denis	janeevytha@gmail.com	60168015846	t	2025-11-09 04:14:38.526128	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "JCIM Area Sabah", "position": "Member"}	2025-11-09 04:14:38.526128	2025-11-09 04:14:38.526128	janeevytha@gmail.com	60168015846	jane evytha denis	\N
1805	9048a301-409a-4b91-ab8d-90b0a2511745	1	1	\N	Nur Azzah Nazihah Binti Ahmad	g-ipgp23071700@moe-dl.edu.my	601136658728	t	2025-11-09 04:14:57.672495	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:14:57.672495	2025-11-09 04:14:57.672495	g-ipgp23071700@moe-dl.edu.my	601136658728	nur azzah nazihah binti ahmad	\N
1808	cac46340-85d4-4ec3-aef8-f68ad5b496d6	1	1	\N	Nurul Hikmah Zainuddin	1998nhzai@gmail.com	60138793274	t	2025-11-09 04:15:47.825617	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Jabatan Bendahari Negeri Sabah", "position": "Penolong Akauntan"}	2025-11-09 04:15:47.825617	2025-11-09 04:15:47.825617	1998nhzai@gmail.com	60138793274	nurul hikmah zainuddin	\N
1809	3ba67691-057b-40ff-a33c-8f6bd2c3414f	1	1	\N	Nurulain Irdina Binti Haiminazran	nurulainirdina14@gmail.com	60138455481	t	2025-11-09 04:15:59.765952	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:15:59.765952	2025-11-09 04:15:59.765952	nurulainirdina14@gmail.com	60138455481	nurulain irdina binti haiminazran	\N
1811	d31c8f46-80d6-4d96-93ec-48c04fa5f965	1	1	\N	Dg. Siti Jamliha Binti Datu Nordin	jamliha1980@gmail.com	60128681891	t	2025-11-09 04:16:36.241483	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "D-Top Motor Parts ", "position": "Workers"}	2025-11-09 04:16:36.241483	2025-11-09 04:16:36.241483	jamliha1980@gmail.com	60128681891	dg. siti jamliha binti datu nordin	\N
1812	b12a0ea8-a894-4d14-8deb-d253bd533b03	1	1	\N	Lawrence Tey Chon Lock	changyungsteel@gmail.com	60168324168	t	2025-11-09 04:17:39.364678	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:17:39.364678	2025-11-09 04:17:39.364678	changyungsteel@gmail.com	60168324168	lawrence tey chon lock	\N
1813	119c21e2-4126-48d8-941b-c072fa41cbfe	1	1	\N	Georgina Reyes Chia	Jreyes8131@gmail.com	60182073669	t	2025-11-09 04:20:13.109908	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Maisarah Time Enterprise ", "position": "Assistance "}	2025-11-09 04:20:13.109908	2025-11-09 04:20:13.109908	jreyes8131@gmail.com	60182073669	georgina reyes chia	\N
1814	c69cbc7d-e63a-4069-9678-3eaba1bb22ac	1	1	\N	Nurul Shafiqah	Ifikah38@yahoo.com	601116697499	t	2025-11-09 04:23:13.579579	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:23:13.579579	2025-11-09 04:23:13.579579	ifikah38@yahoo.com	601116697499	nurul shafiqah	\N
1817	7d2ffb4c-7768-49df-a38c-6047793d0342	1	1	\N	Jane Chong Mei Oi	janecmo78@gmail.com	60168477685	t	2025-11-09 04:26:18.136712	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "#", "position": "#"}	2025-11-09 04:26:18.136712	2025-11-09 04:26:18.136712	janecmo78@gmail.com	60168477685	jane chong mei oi	\N
1818	5ef5fa91-fad2-4be9-9392-21a2b7e9d6b5	1	1	\N	Rosmania Binti Satla	suzierose0@gmail.com	60128305310	t	2025-11-09 04:26:40.090322	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:26:40.090322	2025-11-09 04:26:40.090322	suzierose0@gmail.com	60128305310	rosmania binti satla	\N
1820	7bb05639-7a14-4e2b-8cb7-3bb82fc02f91	1	1	\N	Adriana	adrianagabril.sb@gmail.com	60145717864	t	2025-11-09 04:27:53.81794	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:27:53.81794	2025-11-09 04:27:53.81794	adrianagabril.sb@gmail.com	60145717864	adriana	\N
1821	9a5b8329-5249-4679-9ea8-75934f106fd5	1	1	\N	Synezia Kensiong	smilesynn@gmail.com	60135479319	t	2025-11-09 04:27:54.74471	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:27:54.74471	2025-11-09 04:27:54.74471	smilesynn@gmail.com	60135479319	synezia kensiong	\N
1822	a6f3c0ac-a19e-419e-bdce-f6482d2696aa	1	1	\N	Mohamad Fahim	fahimalimi65265@gmail.com	601158671511	t	2025-11-09 04:27:59.531783	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Smkakk", "position": "Teacher"}	2025-11-09 04:27:59.531783	2025-11-09 04:27:59.531783	fahimalimi65265@gmail.com	601158671511	mohamad fahim	\N
1823	750c67d4-ab0b-403a-a26b-75bfc85c9eb9	1	1	\N	Mohammad Zawawi	mohammadzawawi1998@gmail.com	601123707660	t	2025-11-09 04:28:07.969042	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:28:07.969042	2025-11-09 04:28:07.969042	mohammadzawawi1998@gmail.com	601123707660	mohammad zawawi	\N
1824	b586fc09-33d7-4123-bde8-26df880f2300	1	1	\N	Jaafar Mahmud	jjaafarmahmud@yahoo.com	601116643017	t	2025-11-09 04:28:18.234975	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:28:18.234975	2025-11-09 04:28:18.234975	jjaafarmahmud@yahoo.com	601116643017	jaafar mahmud	\N
1825	976c0a46-2f20-47b8-aae2-64244ea97c3d	1	1	\N	Nuria Massa	aibuayah79@gmail.com	60162312979	t	2025-11-09 04:28:35.45308	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:28:35.45308	2025-11-09 04:28:35.45308	aibuayah79@gmail.com	60162312979	nuria massa	\N
1826	33ebf739-6c01-4bb6-8b89-883a58637e8b	1	1	\N	Koh Siew Tin	kohsiewtin65@gmail.com	60138546370	t	2025-11-09 04:29:05.100055	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:29:05.100055	2025-11-09 04:29:05.100055	kohsiewtin65@gmail.com	60138546370	koh siew tin	\N
1827	e86cd408-6d19-4a1c-af81-b690f10daccf	1	1	\N	Natalie Siew Wei Xuan	natsiew0509@gmail.com	60128876370	t	2025-11-09 04:29:08.838263	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:29:08.838263	2025-11-09 04:29:08.838263	natsiew0509@gmail.com	60128876370	natalie siew wei xuan	\N
1828	864113c7-fc20-4836-90a1-d1d65e96eca0	1	1	\N	Ahmad	NA@gmail.com	60138753113	t	2025-11-09 04:29:38.106623	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:29:38.106623	2025-11-09 04:29:38.106623	na@gmail.com	60138753113	ahmad	\N
1829	1845e5c4-7ce8-49e9-ae50-ee6ff30113fd	1	1	\N	James Ko	Judemanhk@yahoo.com	60128022989	t	2025-11-09 04:29:50.108439	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Multi Link ENT.", "position": "Manager "}	2025-11-09 04:29:50.108439	2025-11-09 04:29:50.108439	judemanhk@yahoo.com	60128022989	james ko	\N
1830	e9a35664-2d05-4316-972f-71ba9d8a670f	1	1	\N	Cyndy	Cyndywei@hotmail.com	60109490644	t	2025-11-09 04:31:15.948676	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Bccm petagas", "position": "Visitor"}	2025-11-09 04:31:15.948676	2025-11-09 04:31:15.948676	cyndywei@hotmail.com	60109490644	cyndy	\N
1831	5e76d522-9bcb-4c35-88b8-eb8ca72e7e8c	1	1	\N	Priscilla	lovely_sog@hotmail.com	60143206866	t	2025-11-09 04:31:19.899379	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "BCCM", "position": "Pastor"}	2025-11-09 04:31:19.899379	2025-11-09 04:31:19.899379	lovely_sog@hotmail.com	60143206866	priscilla	\N
1833	af59234b-fa97-483a-b756-075163dabccf	1	1	\N	Clare	clareaisyahn@gmail.com	60128462779	t	2025-11-09 04:31:39.56539	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 04:31:39.56539	2025-11-09 04:31:39.56539	clareaisyahn@gmail.com	60128462779	clare	\N
1835	d921fd02-33a5-45f8-8207-1c64777b4e8b	1	1	\N	Nurfarhana	farhanasaidi03@gmail.com	60138787870	t	2025-11-09 04:33:58.025538	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 04:33:58.025538	2025-11-09 04:33:58.025538	farhanasaidi03@gmail.com	60138787870	nurfarhana	\N
1836	31ddd66f-8d64-420e-94b8-d160009c7192	1	1	\N	Yusdi Kadir	yusdithegreat@gmail.com	60198610667	t	2025-11-09 04:34:32.630703	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:34:32.630703	2025-11-09 04:34:32.630703	yusdithegreat@gmail.com	60198610667	yusdi kadir	\N
1840	b29842b5-6e43-4e05-80c4-21d727c58355	1	1	\N	Azlina Abdullah @wong Shuk Lin	Azlinawong287@gmail.com	60136447390	t	2025-11-09 04:35:10.274673	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:35:10.274673	2025-11-09 04:35:10.274673	azlinawong287@gmail.com	60136447390	azlina abdullah @wong shuk lin	\N
1842	9b577eee-96b7-4676-b89f-b3705b3c742c	1	1	\N	Syazreeni Rusli	syazreeni.0683@gmail.com	60165094848	t	2025-11-09 04:35:48.980208	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:35:48.980208	2025-11-09 04:35:48.980208	syazreeni.0683@gmail.com	60165094848	syazreeni rusli	\N
1843	9297e5ac-6e5e-48c5-b399-33acfd79da60	1	1	\N	Vianney Michael	Felicitymike48@gmail.com	60198334511	t	2025-11-09 04:36:04.409191	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Unemployed ", "position": "None"}	2025-11-09 04:36:04.409191	2025-11-09 04:36:04.409191	felicitymike48@gmail.com	60198334511	vianney michael	\N
1847	1bff327d-26a2-413b-8ea9-7f285225eaa6	1	1	\N	Maisarah Nasaruddin	maisarah.nasaruddin93@gmail.com	60172745750	t	2025-11-09 04:40:41.650878	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:40:41.650878	2025-11-09 04:40:41.650878	maisarah.nasaruddin93@gmail.com	60172745750	maisarah nasaruddin	\N
1848	cfe4f1df-6507-490f-9174-9d674c3f2c57	1	1	\N	Ktz Enterprise	norazaki6980@gmail.com	601163373567	t	2025-11-09 04:40:47.560654	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 04:40:47.560654	2025-11-09 04:40:47.560654	norazaki6980@gmail.com	601163373567	ktz enterprise	\N
1849	77ed346c-ad7a-4f27-8d9b-1533680ac7ea	1	1	\N	Khadijah Binti Igasan	yatiedpai04@gmail.com	60163630329	t	2025-11-09 04:41:47.947554	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:41:47.947554	2025-11-09 04:41:47.947554	yatiedpai04@gmail.com	60163630329	khadijah binti igasan	\N
1850	53b38621-8c04-4e6c-b830-901b66849d7c	1	1	\N	Rozi Binti Morat	roziemorat@gmail.com	60128355512	t	2025-11-09 04:42:35.590111	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 04:42:35.590111	2025-11-09 04:42:35.590111	roziemorat@gmail.com	60128355512	rozi binti morat	\N
1851	e5c3243f-9017-4aca-aab6-ce1b9c10ab4e	1	1	\N	Ho Yen Ling	hoyenling@gmail.com	60128028895	t	2025-11-09 04:46:16.412595	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 04:46:16.412595	2025-11-09 04:46:16.412595	hoyenling@gmail.com	60128028895	ho yen ling	\N
1852	7aca85e5-4b29-45b9-828e-100ab7909fd0	1	1	\N	Jaini Bin Laini	jainilaini@gmail.com	60143679960	t	2025-11-09 04:51:25.793868	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:51:25.793868	2025-11-09 04:51:25.793868	jainilaini@gmail.com	60143679960	jaini bin laini	\N
1853	320be508-26c3-4f23-a1c3-e143c6048b95	1	1	\N	Susanna	annaby875@gmail.com	60148700777	t	2025-11-09 04:52:18.805566	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 04:52:18.805566	2025-11-09 04:52:18.805566	annaby875@gmail.com	60148700777	susanna	\N
1854	0f0f91a3-017f-462d-86c8-e973ec53db35	1	1	\N	Vivien	Vivienshim1995@gmail.com	601133113137	t	2025-11-09 04:55:57.739222	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Higwhay Transport ", "position": "Secretary "}	2025-11-09 04:55:57.739222	2025-11-09 04:55:57.739222	vivienshim1995@gmail.com	601133113137	vivien	\N
1855	47d39d01-b914-45c7-885b-ff217f023b24	1	1	\N	Stephanie Liew	stephanieliew20@gmail.com	60143590242	t	2025-11-09 04:58:25.763507	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "n/A", "position": "N/A"}	2025-11-09 04:58:25.763507	2025-11-09 04:58:25.763507	stephanieliew20@gmail.com	60143590242	stephanie liew	\N
1856	02fa9bd6-79d3-415f-8acc-3dbdd90efb6d	1	1	\N	Lawrence Chua	kufusab@gmail.com	60133395123	t	2025-11-09 05:00:15.053209	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:00:15.053209	2025-11-09 05:00:15.053209	kufusab@gmail.com	60133395123	lawrence chua	\N
1857	308f283a-6a1f-4298-9a87-a7ee3ee02b73	1	1	\N	Jessie Ang	jash4869@gmail.com	60102171636	t	2025-11-09 05:00:40.217448	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 05:00:40.217448	2025-11-09 05:00:40.217448	jash4869@gmail.com	60102171636	jessie ang	\N
1858	f8bb9950-c91f-4931-8e89-3824819bffb9	1	1	\N	Suhana	Srisuhanq@yahoo.com	60138651030	t	2025-11-09 05:01:58.835806	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 05:01:58.835806	2025-11-09 05:01:58.835806	srisuhanq@yahoo.com	60138651030	suhana	\N
1859	0f2344cf-5ff2-4fb0-8274-b9c1c493b033	1	1	\N	Yusnita	yusnita2010@gmail.com	60138867171	t	2025-11-09 05:03:40.131046	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 05:03:40.131046	2025-11-09 05:03:40.131046	yusnita2010@gmail.com	60138867171	yusnita	\N
1860	62d7a44f-0be3-4bed-a1ef-a790ca8f3280	1	1	\N	Caren	caren_tys@yahoo.com	60168360262	t	2025-11-09 05:05:55.134556	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 05:05:55.134556	2025-11-09 05:05:55.134556	caren_tys@yahoo.com	60168360262	caren	\N
1861	70fa86f6-2bf7-4cda-823d-16078e62ac21	1	1	\N	Christopher Ting	christ9923@gmail.com	60128839923	t	2025-11-09 05:06:25.005786	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "CT Aluminium & Glass", "position": "Director"}	2025-11-09 05:06:25.005786	2025-11-09 05:06:25.005786	christ9923@gmail.com	60128839923	christopher ting	\N
1862	4b1dc4f6-c5cf-4adc-b524-b09bfaf0fa93	1	1	\N	Andriana Dayanti	Andriananesari@gmail.com	601136050061	t	2025-11-09 05:09:05.892864	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 05:09:05.892864	2025-11-09 05:09:05.892864	andriananesari@gmail.com	601136050061	andriana dayanti	\N
1863	ede5ec51-728f-4bb0-ba94-541d04b8ac09	1	1	\N	Simon	Yhsimon@gmail.com	60198527088	t	2025-11-09 05:09:22.4152	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "EIS Industrial ", "position": "Manager"}	2025-11-09 05:09:22.4152	2025-11-09 05:09:22.4152	yhsimon@gmail.com	60198527088	simon	\N
1865	9e861435-6836-4eed-83d1-3e99cae5e4dd	1	1	\N	Princess Padili	Princessp2563@gmail.com	601139972160	t	2025-11-09 05:10:37.299571	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Music Monster Academy ", "position": "Management "}	2025-11-09 05:10:37.299571	2025-11-09 05:10:37.299571	princessp2563@gmail.com	601139972160	princess padili	\N
1867	9f21a90c-f92d-4703-a8ae-3c285e4bb30a	1	1	\N	Mohd Azhar Ramali	azhar.ramali.ar@gmail.com	601139315877	t	2025-11-09 05:11:30.07899	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Cyber Vision Enterprise ", "position": "Manager"}	2025-11-09 05:11:30.07899	2025-11-09 05:11:30.07899	azhar.ramali.ar@gmail.com	601139315877	mohd azhar ramali	\N
1868	294ea6a0-6803-44d8-ad9d-969583d5e104	1	1	\N	Norman	Normanamman047@gmail.com	601131524057	t	2025-11-09 05:12:00.497255	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Kedai runcit azhar ", "position": "Operations "}	2025-11-09 05:12:00.497255	2025-11-09 05:12:00.497255	normanamman047@gmail.com	601131524057	norman	\N
1869	4f6f019b-709a-4352-b15c-c0d377092a8b	1	1	\N	Shirley Tsen	sharribozu_811@yahoo.com	601133999330	t	2025-11-09 05:18:59.588988	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 05:18:59.588988	2025-11-09 05:18:59.588988	sharribozu_811@yahoo.com	601133999330	shirley tsen	\N
1872	233cf78b-f614-4d91-8d1d-ecd22f97aa5c	1	1	\N	Nuramirah Qistina Binti Baslan	nurqisbaslan07@gmail.coom	60145511963	t	2025-11-09 05:21:17.29908	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "custumer"}	2025-11-09 05:21:17.29908	2025-11-09 05:21:17.29908	nurqisbaslan07@gmail.coom	60145511963	nuramirah qistina binti baslan	\N
1873	d498305d-350b-44cb-bcc7-b7f8d8a4f861	1	1	\N	Joanna	Joannayang44@gmail.com	60109309282	t	2025-11-09 05:21:36.458537	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Excel success Sdn bhd", "position": "Director"}	2025-11-09 05:21:36.458537	2025-11-09 05:21:36.458537	joannayang44@gmail.com	60109309282	joanna	\N
1874	d59fdb85-d23f-488b-9ccf-5c5b24679eff	1	1	\N	Gorden Ho Yong Hao	gordenho8@gmail.com	60167531005	t	2025-11-09 05:25:01.66728	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Naa", "position": "NA"}	2025-11-09 05:25:01.66728	2025-11-09 05:25:01.66728	gordenho8@gmail.com	60167531005	gorden ho yong hao	\N
1875	eacf6c55-d059-4c52-9855-d65a441be717	1	1	\N	Arfan Bin Nordin	arapang94@gmail.com	60139057668	t	2025-11-09 05:26:06.514335	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SKM", "position": "none"}	2025-11-09 05:26:06.514335	2025-11-09 05:26:06.514335	arapang94@gmail.com	60139057668	arfan bin nordin	\N
1876	750bec45-7525-4e47-a333-7d46d94c011a	1	1	\N	Junaidi Titu	jtitu08@gmail.com	60168436500	t	2025-11-09 05:26:39.496995	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:26:39.496995	2025-11-09 05:26:39.496995	jtitu08@gmail.com	60168436500	junaidi titu	\N
1877	4bb561ff-1416-4d1a-8716-e49581f80f4d	1	1	\N	Mohd Zikri Zainudin	brozikri@gmail.com	60138830445	t	2025-11-09 05:27:25.1986	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "ABIM ", "position": "YDP "}	2025-11-09 05:27:25.1986	2025-11-09 05:27:25.1986	brozikri@gmail.com	60138830445	mohd zikri zainudin	\N
1878	b6b71da6-19c9-4c82-99a1-b308542496fa	1	1	\N	Rachel	Shanellefung@gmail.com	60128166678	t	2025-11-09 05:27:42.410136	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Pancar jaya ", "position": "Sales"}	2025-11-09 05:27:42.410136	2025-11-09 05:27:42.410136	shanellefung@gmail.com	60128166678	rachel	\N
1880	3a7a401a-0eae-40e1-93d2-3bf3d73b7109	1	1	\N	Yatthie	yatthie@gmail.com	60198426509	t	2025-11-09 05:28:51.133784	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah Government Teachers' Union", "position": "Operation Executive Admin"}	2025-11-09 05:28:51.133784	2025-11-09 05:28:51.133784	yatthie@gmail.com	60198426509	yatthie	\N
1882	97cdfe6d-5472-4db4-9b8f-32c6842d49ac	1	1	\N	Lo Lian Jin	lo.lianjin@gmail.com	60168187993	t	2025-11-09 05:36:14.469775	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:36:14.469775	2025-11-09 05:36:14.469775	lo.lianjin@gmail.com	60168187993	lo lian jin	\N
1883	d977d3b9-1c01-4bc3-92f2-e0bc32a962d5	1	1	\N	Benny	lanice_ng@yahoo.com	60168260624	t	2025-11-09 05:36:19.105236	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "A1", "position": "Director"}	2025-11-09 05:36:19.105236	2025-11-09 05:36:19.105236	lanice_ng@yahoo.com	60168260624	benny	\N
1884	f5e7478a-4070-4377-ba75-a49a5561aaed	1	1	\N	Tan Guan Soon	tgs8833@gmail.com	60178186633	t	2025-11-09 05:37:03.129526	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Empire Treasure Club Sdn Bhd", "position": "Managing Director"}	2025-11-09 05:37:03.129526	2025-11-09 05:37:03.129526	tgs8833@gmail.com	60178186633	tan guan soon	\N
1885	7bcdb64f-0b5a-426e-aa22-3a47c61d563a	1	1	\N	Ken Hsu	Kenhsu0704@gmail.com	60109580407	t	2025-11-09 05:37:32.037208	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "4pri7 SDN BHD ", "position": "Managing director "}	2025-11-09 05:37:32.037208	2025-11-09 05:37:32.037208	kenhsu0704@gmail.com	60109580407	ken hsu	\N
1886	9945e383-8534-4668-a7cd-88060eadf9bd	1	1	\N	Dauna Koijin	daunakoijin@gmail.com	60193005107	t	2025-11-09 05:38:05.211535	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:38:05.211535	2025-11-09 05:38:05.211535	daunakoijin@gmail.com	60193005107	dauna koijin	\N
1891	7f0d0329-d340-4acd-bbdf-abd664c7a38f	1	1	\N	Ak Lumin	hak.lumn@gmail.cim	601112052030	t	2025-11-09 05:43:59.651438	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 05:43:59.651438	2025-11-09 05:43:59.651438	hak.lumn@gmail.cim	601112052030	ak lumin	\N
1892	58c7494a-62de-4d1e-b702-b18df95293d3	1	1	\N	Ken Lim	kenl@live.com.my	60178367718	t	2025-11-09 05:44:11.34154	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Creative Promotion Channel Sdn Bhd", "position": "Director"}	2025-11-09 05:44:11.34154	2025-11-09 05:44:11.34154	kenl@live.com.my	60178367718	ken lim	\N
1893	c1067661-fefb-485e-ae35-7a493a77568a	1	1	\N	Nursatiah	Nursatiah13@gmail.com	601135612160	t	2025-11-09 05:48:00.362961	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:48:00.362961	2025-11-09 05:48:00.362961	nursatiah13@gmail.com	601135612160	nursatiah	\N
1894	55edbb2e-4c31-438a-b3d8-7cde8ae7566c	1	1	\N	Rinawati Binti Ahmad	Iidrisrina@gmail.com	60196678376	t	2025-11-09 05:48:22.713024	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:48:22.713024	2025-11-09 05:48:22.713024	iidrisrina@gmail.com	60196678376	rinawati binti ahmad	\N
1895	f0ca996e-9f0f-459e-9edc-2da7e7e96f2e	1	1	\N	Ainabintirudi	Ainarudi8@gmail.com	60193074820	t	2025-11-09 05:48:22.968466	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 05:48:22.968466	2025-11-09 05:48:22.968466	ainarudi8@gmail.com	60193074820	ainabintirudi	\N
1897	a0c81cdd-3e41-44ff-b2a8-3fb16983d031	1	1	\N	Nicholson Nicholas Wong	crouchrollsleep@gmail.com	60149577144	t	2025-11-09 05:51:27.976157	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Freelancer", "position": "Graphic Designer"}	2025-11-09 05:51:27.976157	2025-11-09 05:51:27.976157	crouchrollsleep@gmail.com	60149577144	nicholson nicholas wong	\N
1898	4285304f-9345-4f8c-aa40-cda7cfb8a0d7	1	1	\N	Naufal	naufalfudil11@gmail.com	601111293710	t	2025-11-09 05:51:48.39839	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 05:51:48.39839	2025-11-09 05:51:48.39839	naufalfudil11@gmail.com	601111293710	naufal	\N
1900	b4437463-59ac-47b4-9108-ae36b26494c9	1	1	\N	Aztuty	aztutyy12@gmail.com	60149081218	t	2025-11-09 05:52:04.601136	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 05:52:04.601136	2025-11-09 05:52:04.601136	aztutyy12@gmail.com	60149081218	aztuty	\N
1901	432eb2cf-a5c8-4f29-b228-e1996740945e	1	1	\N	Norpadila Binti Smah	dilalasmah@gmail.com	60189655331	t	2025-11-09 05:52:49.396319	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 05:52:49.396319	2025-11-09 05:52:49.396319	dilalasmah@gmail.com	60189655331	norpadila binti smah	\N
1902	3597dcf6-21b6-4849-883c-566b786308bd	1	1	\N	Dayang Noraina Binti Nordin	noraina7181@gmail.com	60189629037	t	2025-11-09 05:52:50.330052	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 05:52:50.330052	2025-11-09 05:52:50.330052	noraina7181@gmail.com	60189629037	dayang noraina binti nordin	\N
1903	c6b27c13-be73-4649-9a55-58a8aea509d1	1	1	\N	Jon Wong	vvcs1994@gmail.com	60128009498	t	2025-11-09 05:53:18.07656	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "YTL", "position": "exec"}	2025-11-09 05:53:18.07656	2025-11-09 05:53:18.07656	vvcs1994@gmail.com	60128009498	jon wong	\N
1904	cb2a7719-40a4-40b3-af10-67170c351e0c	1	1	\N	Rose Tsen	rosetsen0619@gmail.com	60168333666	t	2025-11-09 05:58:22.423494	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Chan Furniture", "position": "Director"}	2025-11-09 05:58:22.423494	2025-11-09 05:58:22.423494	rosetsen0619@gmail.com	60168333666	rose tsen	\N
1905	aa49fb7d-44b2-4076-a574-29614cfb1644	1	1	\N	Yong Li Ha	Yonglh2012@gmail.com	60146515256	t	2025-11-09 06:07:52.466402	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:07:52.466402	2025-11-09 06:07:52.466402	yonglh2012@gmail.com	60146515256	yong li ha	\N
1906	86e3fe02-fba9-4e6f-9489-ef06ebed6b53	1	1	\N	Young Kids. Yin	Monica.yongki.yin@gmail.com	60138961155	t	2025-11-09 06:10:17.313564	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:10:17.313564	2025-11-09 06:10:17.313564	monica.yongki.yin@gmail.com	60138961155	young kids. yin	\N
1908	d72baec1-cc11-412d-aa8b-67842bb1a6c0	1	1	\N	Yong Lee Fong	Yongsusan97@yahoo.com	60168156281	t	2025-11-09 06:13:50.799937	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "Mo"}	2025-11-09 06:13:50.799937	2025-11-09 06:13:50.799937	yongsusan97@yahoo.com	60168156281	yong lee fong	\N
1909	1d303116-37dd-4585-bc44-0841ad01cfd6	1	1	\N	Joshua	pwhii74@gmail.com	60189696451	t	2025-11-09 06:14:01.030806	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:14:01.030806	2025-11-09 06:14:01.030806	pwhii74@gmail.com	60189696451	joshua	\N
1910	3310daf1-811b-4053-9bbf-45f7ce753a1e	1	1	\N	Chen Pui Siam	chenpuisiam@gmail.com	60168391564	t	2025-11-09 06:14:27.765191	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:14:27.765191	2025-11-09 06:14:27.765191	chenpuisiam@gmail.com	60168391564	chen pui siam	\N
1911	10ae1284-cf11-4597-aef9-6460d8f73c4c	1	1	\N	Chen Pui Yee	Gracecpy75@gmail.com	60188744755	t	2025-11-09 06:15:03.473096	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 06:15:03.473096	2025-11-09 06:15:03.473096	gracecpy75@gmail.com	60188744755	chen pui yee	\N
1912	827e6c75-6841-4eb6-8ea7-6a64910782d6	1	1	\N	Hane	nrfadzrianie02@gmail.com	601114106267	t	2025-11-09 06:15:34.88394	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "SAWIT KINABALU GROUP", "position": "SENIOR ASSISTANT"}	2025-11-09 06:15:34.88394	2025-11-09 06:15:34.88394	nrfadzrianie02@gmail.com	601114106267	hane	\N
1913	97891417-6439-473c-bca2-8736f9623589	1	1	\N	Nur Afiana	nurafiana1451@gmail.con	60164873076	t	2025-11-09 06:15:45.390674	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:15:45.390674	2025-11-09 06:15:45.390674	nurafiana1451@gmail.con	60164873076	nur afiana	\N
1914	1bd9cff9-914d-4f58-8c43-0042d5f17a84	1	1	\N	Iffa Azwanie	iffaazwanie@gmail.com	601151700741	t	2025-11-09 06:15:48.678087	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:15:48.678087	2025-11-09 06:15:48.678087	iffaazwanie@gmail.com	601151700741	iffa azwanie	\N
1915	c405b6d6-d655-466e-94f8-103536fc0afe	1	1	\N	Syazwani	syazwanisujasny@gmail.com	60142245602	t	2025-11-09 06:15:49.931558	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:15:49.931558	2025-11-09 06:15:49.931558	syazwanisujasny@gmail.com	60142245602	syazwani	\N
1918	ddc640a7-1abe-419f-be5a-ea851d396b90	1	1	\N	Yongleiling	lely92903@gmail.com	60168386378	t	2025-11-09 06:16:39.833763	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:16:39.833763	2025-11-09 06:16:39.833763	lely92903@gmail.com	60168386378	yongleiling	\N
1919	f54bc036-531e-4a30-8536-6651e44e569b	1	1	\N	Edoh Ibon	edora5375@gmail.com	60198287181	t	2025-11-09 06:17:02.105169	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 06:17:02.105169	2025-11-09 06:17:02.105169	edora5375@gmail.com	60198287181	edoh ibon	\N
1920	15784c2b-5e59-4b76-985f-6a522be636a0	1	1	\N	Sugumaran	sugukula@gmail.com	601121704723	t	2025-11-09 06:17:59.348725	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:17:59.348725	2025-11-09 06:17:59.348725	sugukula@gmail.com	601121704723	sugumaran	\N
1921	4ac45daa-1ea0-418f-a03c-b9b693ca0b3f	1	1	\N	Yong Lee Hung	helenyleehung@gmail.com	60168176878	t	2025-11-09 06:18:46.207727	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 06:18:46.207727	2025-11-09 06:18:46.207727	helenyleehung@gmail.com	60168176878	yong lee hung	\N
1922	d91b2ec8-31d5-40ba-b0d6-f35a3ed09e07	1	1	\N	Clyryse Andgelynna Wong	Andgelynnaclyryse@gmail.com	60134442629	t	2025-11-09 06:25:50.303257	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Maxia", "position": "Sales"}	2025-11-09 06:25:50.303257	2025-11-09 06:25:50.303257	andgelynnaclyryse@gmail.com	60134442629	clyryse andgelynna wong	\N
1923	00760abb-75d1-4231-9d19-325f6a0a3801	1	1	\N	Eric	ericwcf1018@gmail.com	601151658330	t	2025-11-09 06:26:26.773489	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Rock Maestro", "position": "Direct Sales Executive"}	2025-11-09 06:26:26.773489	2025-11-09 06:26:26.773489	ericwcf1018@gmail.com	601151658330	eric	\N
1924	20bed99b-9765-49d7-9012-238404dd6a9d	1	1	\N	Lone	Berthlone98@gmail.com	60148515675	t	2025-11-09 06:26:27.235969	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 06:26:27.235969	2025-11-09 06:26:27.235969	berthlone98@gmail.com	60148515675	lone	\N
1925	8d462084-e557-428a-9237-1153e1cda784	1	1	\N	Clay	Clayone89@gmail.com	60109486922	t	2025-11-09 06:26:28.195898	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 06:26:28.195898	2025-11-09 06:26:28.195898	clayone89@gmail.com	60109486922	clay	\N
1926	e175f74a-3a09-498d-a378-ecc5752c35e6	1	1	\N	Ryan Ang	Mingru1@hotmail.com	60128855741	t	2025-11-09 06:29:04.106874	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:29:04.106874	2025-11-09 06:29:04.106874	mingru1@hotmail.com	60128855741	ryan ang	\N
1927	608cfe40-b5da-487d-87e8-a34aa139aa96	1	1	\N	Jimmy Then	Jimmytmm@gmail.com	60198807987	t	2025-11-09 06:34:17.084749	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:34:17.084749	2025-11-09 06:34:17.084749	jimmytmm@gmail.com	60198807987	jimmy then	\N
1928	9ecc410e-6feb-4fdb-8321-155072fde880	1	1	\N	Michelle Wong	pgstwu@gmail.com	60198736422	t	2025-11-09 06:35:30.897413	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:35:30.897413	2025-11-09 06:35:30.897413	pgstwu@gmail.com	60198736422	michelle wong	\N
1929	c6797d6b-0f26-4205-bcd4-c2eb44219188	1	1	\N	Teh Ka Min	artictea@gmail.com	60143710728	t	2025-11-09 06:35:36.624114	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 06:35:36.624114	2025-11-09 06:35:36.624114	artictea@gmail.com	60143710728	teh ka min	\N
1930	87b4661d-9494-4b1c-b65f-bcb22f572d54	1	1	\N	Aldric Wu	Aldricwu97@gmail.com	60143571997	t	2025-11-09 06:36:09.262528	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "The oak steert", "position": "N/A"}	2025-11-09 06:36:09.262528	2025-11-09 06:36:09.262528	aldricwu97@gmail.com	60143571997	aldric wu	\N
1931	b4d49bba-ecf6-478d-848d-b39597bc5f79	1	1	\N	Saadan	iphonesaadan@gmail.com	60102166865	t	2025-11-09 06:40:30.516483	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Saadan", "position": "Kerani"}	2025-11-09 06:40:30.516483	2025-11-09 06:40:30.516483	iphonesaadan@gmail.com	60102166865	saadan	\N
1932	639f40f0-c784-41fd-a51d-77e47d7a748b	1	1	\N	Alan Kong	alanjr888@gmail.com	60143552717	t	2025-11-09 06:47:42.045237	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 06:47:42.045237	2025-11-09 06:47:42.045237	alanjr888@gmail.com	60143552717	alan kong	\N
1933	7c5e781d-741e-40f3-96f2-55caddc47a45	1	1	\N	Norliyana Nasbi	liyananasbi91@gmail.com	60198036624	t	2025-11-09 06:52:12.029781	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 06:52:12.029781	2025-11-09 06:52:12.029781	liyananasbi91@gmail.com	60198036624	norliyana nasbi	\N
1934	cd4db800-18ff-4ca4-9293-70f771427cb3	1	1	\N	Rusida Binti Mohd Tam	Rusida8796@gmail.com	60168438796	t	2025-11-09 06:59:28.00805	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-09 06:59:28.00805	2025-11-09 06:59:28.00805	rusida8796@gmail.com	60168438796	rusida binti mohd tam	\N
1935	8b00d095-3d52-4ba3-8d86-3208449039e2	1	1	\N	Nurul Afika	afika1238@gmail.com	60102850079	t	2025-11-09 06:59:49.527048	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Firesafe Services Sdn Bhd", "position": "Account Assistant"}	2025-11-09 06:59:49.527048	2025-11-09 06:59:49.527048	afika1238@gmail.com	60102850079	nurul afika	\N
1936	36873aed-7983-4692-bb9d-ed3b3ad11925	1	1	\N	Norfauziah Binti Andan	norfauziahandan85@gmail.com	601124466134	t	2025-11-09 07:02:23.464686	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 07:02:23.464686	2025-11-09 07:02:23.464686	norfauziahandan85@gmail.com	601124466134	norfauziah binti andan	\N
1937	bed81387-8598-4e11-baf4-47236f5831bc	1	1	\N	Nur Nasiha Binti Hassan	chiachanel93@yahoo.com	60162055124	t	2025-11-09 07:02:50.0468	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 07:02:50.0468	2025-11-09 07:02:50.0468	chiachanel93@yahoo.com	60162055124	nur nasiha binti hassan	\N
1938	8389ce8c-d0d7-46dd-a025-4404b85608da	1	1	\N	石红雨	357072153@qq.com	601139209808	t	2025-11-09 07:03:21.775831	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:03:21.775831	2025-11-09 07:03:21.775831	357072153@qq.com	601139209808	石红雨	\N
1939	5e1d258e-6fda-46a5-a555-2c196816b779	1	1	\N	Nurhida Binti Muksin	Nurhisanur49@gmail.com	601125413503	t	2025-11-09 07:03:51.770394	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "no"}	2025-11-09 07:03:51.770394	2025-11-09 07:03:51.770394	nurhisanur49@gmail.com	601125413503	nurhida binti muksin	\N
1940	42a5cb38-b4d7-4388-9849-d48be9682422	1	1	\N	Nurhidrah Mukhsin	Adamsha.@gmail.com	60166033840	t	2025-11-09 07:04:53.965566	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-09 07:04:53.965566	2025-11-09 07:04:53.965566	adamsha.@gmail.com	60166033840	nurhidrah mukhsin	\N
1941	a52417ed-13ae-4507-a0dc-ad34b5e3d228	1	1	\N	Zhushengzhao	953624283@qq.com	60106670710	t	2025-11-09 07:05:16.664375	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "na", "position": "na"}	2025-11-09 07:05:16.664375	2025-11-09 07:05:16.664375	953624283@qq.com	60106670710	zhushengzhao	\N
1942	841af410-0e06-4038-80e6-b82abd49ebf9	1	1	\N	Stephen	Poboxcombo@yahoo.com	60109322168	t	2025-11-09 07:06:28.84057	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:06:28.84057	2025-11-09 07:06:28.84057	poboxcombo@yahoo.com	60109322168	stephen	\N
1943	fe63100f-9b0a-4a37-b2d8-1f3ea1bd5843	1	1	\N	Jahufar Aliumer	jaliumer@yahoo.com	60198229786	t	2025-11-09 07:07:36.722247	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabaras", "position": "Manager"}	2025-11-09 07:07:36.722247	2025-11-09 07:07:36.722247	jaliumer@yahoo.com	60198229786	jahufar aliumer	\N
1944	7c38a216-31f0-4491-a58f-b28dbecdc35e	1	1	\N	Deo Avanus Teddy	deoaltacc@gmail.com	601126150988	t	2025-11-09 07:10:59.85569	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "N/A", "position": "N/A"}	2025-11-09 07:10:59.85569	2025-11-09 07:10:59.85569	deoaltacc@gmail.com	601126150988	deo avanus teddy	\N
1945	c1e20f9d-ee12-405e-9b3f-2e9f1b285091	1	1	\N	Asiah Abidin	abidinasiah@gmail.com	60198535274	t	2025-11-09 07:12:34.34917	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 07:12:34.34917	2025-11-09 07:12:34.34917	abidinasiah@gmail.com	60198535274	asiah abidin	\N
1946	0d5d5755-1c1d-49d8-bf83-dd2f55f452d4	1	1	\N	Nanyo	minyusaleh@gmail.com	60123897224	t	2025-11-09 07:12:37.174639	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "na", "position": "na"}	2025-11-09 07:12:37.174639	2025-11-09 07:12:37.174639	minyusaleh@gmail.com	60123897224	nanyo	\N
1947	f13be6f5-1150-4d13-b7af-080a8ce67778	1	1	\N	Elaina	airaelaina@gmail.com	60168193378	t	2025-11-09 07:14:36.108467	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:14:36.108467	2025-11-09 07:14:36.108467	airaelaina@gmail.com	60168193378	elaina	\N
1948	54b22fd7-61a7-4f84-8cc3-449de0fbeed7	1	1	\N	Sandra Heng	hengsandra@yahoo.com	60168333308	t	2025-11-09 07:14:48.561488	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:14:48.561488	2025-11-09 07:14:48.561488	hengsandra@yahoo.com	60168333308	sandra heng	\N
1949	001bbad0-9246-4ba5-b955-75b050c89d6b	1	1	\N	Alex Yong	vanalex60@gmail.com	60128866673	t	2025-11-09 07:15:01.252737	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Blue Ocean Marinas Sdn Bhd", "position": "Managing Director"}	2025-11-09 07:15:01.252737	2025-11-09 07:15:01.252737	vanalex60@gmail.com	60128866673	alex yong	\N
1951	9c044948-011a-4bf7-88a4-c150e1dc12a2	1	1	\N	Sitti Ainah Binti Amsain	SittiAinah84@gmail.com	60109888725	t	2025-11-09 07:15:17.148779	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "Na"}	2025-11-09 07:15:17.148779	2025-11-09 07:15:17.148779	sittiainah84@gmail.com	60109888725	sitti ainah binti amsain	\N
1952	9396dbda-9da0-4cbc-8643-bea680f77ed3	1	1	\N	Razmahwati	manismaniss941@gmail.com	601121831652	t	2025-11-09 07:15:19.330677	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:15:19.330677	2025-11-09 07:15:19.330677	manismaniss941@gmail.com	601121831652	razmahwati	\N
1953	6219e5ea-b911-4e48-9bcf-c4d4c9732b33	1	1	\N	Siti Sharizah Binti Asaat	Sitisharizahsanam@gmail.com	60165523431	t	2025-11-09 07:15:38.171628	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 07:15:38.171628	2025-11-09 07:15:38.171628	sitisharizahsanam@gmail.com	60165523431	siti sharizah binti asaat	\N
1954	f6d34b1f-01a7-4558-a902-364a2a673a3a	1	1	\N	Siti Nurul Nazwa Binti Asaat	sitinurulnazwaatsaat@gmail.com	601114394462	t	2025-11-09 07:16:26.221414	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "Na"}	2025-11-09 07:16:26.221414	2025-11-09 07:16:26.221414	sitinurulnazwaatsaat@gmail.com	601114394462	siti nurul nazwa binti asaat	\N
1955	b19ab383-43fe-4030-8cb0-5c06066c2684	1	1	\N	Georgina Reyes Chia	Juriahchia.abd@gmail.com	60182073669	t	2025-11-09 07:18:54.438789	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 07:18:54.438789	2025-11-09 07:18:54.438789	juriahchia.abd@gmail.com	60182073669	georgina reyes chia	\N
1956	ee62ab6d-d735-4e93-a06b-1ca079d87e21	1	1	\N	Fazierah Binti Zulkarnain	fransria86@gmail.com	60163873347	t	2025-11-09 07:19:04.068816	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Riaeira pearl craft ", "position": "Business "}	2025-11-09 07:19:04.068816	2025-11-09 07:19:04.068816	fransria86@gmail.com	60163873347	fazierah binti zulkarnain	\N
1957	f4548591-243f-4ff3-b042-1d8b3bbfe579	1	1	\N	Wilary Photographer	wiwilary88@gmail.com	60138652688	t	2025-11-09 07:19:39.782996	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:19:39.782996	2025-11-09 07:19:39.782996	wiwilary88@gmail.com	60138652688	wilary photographer	\N
1958	2c461ce5-63ce-4d83-92ed-a98fecd778bd	1	1	\N	Fairus	fairus680701@gmail.com	60178649225	t	2025-11-09 07:20:13.675532	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:20:13.675532	2025-11-09 07:20:13.675532	fairus680701@gmail.com	60178649225	fairus	\N
1959	df2758b7-8342-4ee6-ab6a-abcadca63437	1	1	\N	Nurfarah Diba Binti Mohd Din@dino	nfarahdibs.dno@gmail.com	60147045761	t	2025-11-09 07:27:57.389137	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 07:27:57.389137	2025-11-09 07:27:57.389137	nfarahdibs.dno@gmail.com	60147045761	nurfarah diba binti mohd din@dino	\N
1960	72351473-5838-4c25-a86c-470d455b2204	1	1	\N	Sheryl Yap	Yapyan96@gmail.com	60162792196	t	2025-11-09 07:28:56.878099	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Cocoa kingdom", "position": "Pastry"}	2025-11-09 07:28:56.878099	2025-11-09 07:28:56.878099	yapyan96@gmail.com	60162792196	sheryl yap	\N
1961	5ee95a54-d35d-4311-a0ce-5c4b7f24b2fd	1	1	\N	Rafi	rafiuddinmuhd5@gmail.com	601119998259	t	2025-11-09 07:30:49.131094	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "City top", "position": "Drafter"}	2025-11-09 07:30:49.131094	2025-11-09 07:30:49.131094	rafiuddinmuhd5@gmail.com	601119998259	rafi	\N
1962	47698290-fdf6-4c19-944b-3ef6c8bcd2f2	1	1	\N	Zuliaa	zuliasari030800@gmail.com	601136941447	t	2025-11-09 07:31:15.325586	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Ksafe ", "position": "-"}	2025-11-09 07:31:15.325586	2025-11-09 07:31:15.325586	zuliasari030800@gmail.com	601136941447	zuliaa	\N
1963	fb8ccae8-82a4-4c17-a4ae-84131ba80710	1	1	\N	Aaron	akeano@gmail.com	60198806091	t	2025-11-09 07:33:05.094821	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:33:05.094821	2025-11-09 07:33:05.094821	akeano@gmail.com	60198806091	aaron	\N
1964	67687d4d-41f7-4c03-bfc6-98582898cd7f	1	1	\N	Lui Jun Li	Junsky1999@gmail.com	60128265142	t	2025-11-09 07:35:25.399903	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:35:25.399903	2025-11-09 07:35:25.399903	junsky1999@gmail.com	60128265142	lui jun li	\N
1965	8b87ea1b-c3d0-48eb-a96e-c7da2f7028a7	1	1	\N	Awangku Nazaruddin	Rudytg@gmail.com	60107667076	t	2025-11-09 07:35:29.942821	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Innoprise Corporation", "position": "General Manager"}	2025-11-09 07:35:29.942821	2025-11-09 07:35:29.942821	rudytg@gmail.com	60107667076	awangku nazaruddin	\N
1967	95387cca-488f-4728-b279-cd15ced12c28	1	1	\N	Nur Shima Naney	shimananey@gmail.com	60109478941	t	2025-11-09 07:42:14.281145	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 07:42:14.281145	2025-11-09 07:42:14.281145	shimananey@gmail.com	60109478941	nur shima naney	\N
1970	d9954466-8d4a-4cc8-98ce-b8b5fb16567b	1	1	\N	Jay Tan	superjtan@gmail.com	60165093363	t	2025-11-09 07:45:57.85366	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Bellz Studio", "position": "Wellness coach"}	2025-11-09 07:45:57.85366	2025-11-09 07:45:57.85366	superjtan@gmail.com	60165093363	jay tan	\N
1971	577ff2ff-2974-41dc-85ca-aa679e5eb5c4	1	1	\N	Nurjan	mohdnurjan7@gmail.com	601126867109	t	2025-11-09 07:47:42.438545	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": ",", "position": ","}	2025-11-09 07:47:42.438545	2025-11-09 07:47:42.438545	mohdnurjan7@gmail.com	601126867109	nurjan	\N
1972	70c100ae-5d6c-4cfb-8eae-761463afecba	1	1	\N	Margaret Chen	NA@gmail.com	60168862061	t	2025-11-09 07:48:23.271967	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:48:23.271967	2025-11-09 07:48:23.271967	na@gmail.com	60168862061	margaret chen	\N
1973	b0268ba1-0d56-4b19-8b25-c3b0c17b29fd	1	1	\N	Chen Kin Hui	jenniferkhchen@hotmail.com	60168493555	t	2025-11-09 07:48:36.782611	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:48:36.782611	2025-11-09 07:48:36.782611	jenniferkhchen@hotmail.com	60168493555	chen kin hui	\N
1974	92d64f3a-13b8-4c06-b808-62c706cbdb61	1	1	\N	Sinang	Na@gmail.com	60162971751	t	2025-11-09 07:48:38.904992	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Z", "position": "Z"}	2025-11-09 07:48:38.904992	2025-11-09 07:48:38.904992	na@gmail.com	60162971751	sinang	\N
1975	6cfa5cee-6186-47ab-930c-6961eba1530c	1	1	\N	Wwinnie	Qaproses@gmail.com	60168068807	t	2025-11-09 07:48:41.746296	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Qa network", "position": "Direcror"}	2025-11-09 07:48:41.746296	2025-11-09 07:48:41.746296	qaproses@gmail.com	60168068807	wwinnie	\N
1976	5bbb8bd9-baa0-42d9-b570-085a1410e178	1	1	\N	Ana	Na@gmail.com	601126728202	t	2025-11-09 07:48:50.293681	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "No", "position": "No"}	2025-11-09 07:48:50.293681	2025-11-09 07:48:50.293681	na@gmail.com	601126728202	ana	\N
1977	d774fe49-95e4-421c-904a-efd491300371	1	1	\N	Norhana	Na@gmail.com	60165767708	t	2025-11-09 07:49:14.361326	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "F", "position": "D"}	2025-11-09 07:49:14.361326	2025-11-09 07:49:14.361326	na@gmail.com	60165767708	norhana	\N
1979	6ac3d8ab-9e70-4645-b8b2-44c080181b05	1	1	\N	Gerald Vincent	rgeraldvincentimbi@gmail.com	60198827300	t	2025-11-09 07:55:12.364094	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 07:55:12.364094	2025-11-09 07:55:12.364094	rgeraldvincentimbi@gmail.com	60198827300	gerald vincent	\N
1980	d39fbb49-a3a1-4543-8fa2-efee16a0ca2c	1	1	\N	David Yong	davidyong3173@gmail.com	60168183369	t	2025-11-09 08:00:09.978858	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 08:00:09.978858	2025-11-09 08:00:09.978858	davidyong3173@gmail.com	60168183369	david yong	\N
1981	e2430763-a8df-41fc-9b9a-f66f64c00559	1	1	\N	Sanny Liew	sanny02022022@gmail.com	60168331449	t	2025-11-09 08:01:20.567778	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "na"}	2025-11-09 08:01:20.567778	2025-11-09 08:01:20.567778	sanny02022022@gmail.com	60168331449	sanny liew	\N
1982	1a9b60c3-88fa-4e4f-a8c8-4e099fc6cc95	1	1	\N	Peter Bin Sumping	petersumping1961@gmail.com	60128373561	t	2025-11-09 08:01:29.674121	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:01:29.674121	2025-11-09 08:01:29.674121	petersumping1961@gmail.com	60128373561	peter bin sumping	\N
1983	6e36cffd-2e25-499a-81f4-e13115b21500	1	1	\N	Yun Ahmad	blackyune@ymail.com	60133399165	t	2025-11-09 08:06:26.41112	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:06:26.41112	2025-11-09 08:06:26.41112	blackyune@ymail.com	60133399165	yun ahmad	\N
1984	1537c5d4-357b-4009-8b49-db46e984fd41	1	1	\N	Ayie Lee	wajahtimur.aroundtheworld1@yahoo.com	60133399167	t	2025-11-09 08:06:41.405687	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:06:41.405687	2025-11-09 08:06:41.405687	wajahtimur.aroundtheworld1@yahoo.com	60133399167	ayie lee	\N
1985	1f3cf13f-760c-42b4-8325-9a9207b8fe14	1	1	\N	Fiza	viefiza@yahoo.com.my	60148668320	t	2025-11-09 08:06:41.924532	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Na", "position": "Na"}	2025-11-09 08:06:41.924532	2025-11-09 08:06:41.924532	viefiza@yahoo.com.my	60148668320	fiza	\N
1986	a151b48c-9a7c-47f2-b18c-591983cee4f5	1	1	\N	Hazirah Abdul Mumin	hazirahradzy87@gmail.com	60198751887	t	2025-11-09 08:07:39.294725	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Se", "position": "Assistant admin"}	2025-11-09 08:07:39.294725	2025-11-09 08:07:39.294725	hazirahradzy87@gmail.com	60198751887	hazirah abdul mumin	\N
1987	5b1f1021-b134-49df-9a53-b0e70f9bcf46	1	1	\N	Mohammad Fikri	Mrfiq@yahoo.com	60198928575	t	2025-11-09 08:07:41.098043	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sabah electricity", "position": "Auditor"}	2025-11-09 08:07:41.098043	2025-11-09 08:07:41.098043	mrfiq@yahoo.com	60198928575	mohammad fikri	\N
1988	2c23377e-11bd-4d48-a8fd-dd8fca4eac4d	1	1	\N	Md Razie Maidi	Radzie_rajz88@yahoo.com	60138990502	t	2025-11-09 08:07:42.562121	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Bank muamalat ", "position": "Banker"}	2025-11-09 08:07:42.562121	2025-11-09 08:07:42.562121	radzie_rajz88@yahoo.com	60138990502	md razie maidi	\N
1989	72458d14-810c-4743-8db7-813a3d762249	1	1	\N	Eva Juan	evriean@gmail.com	601119881344	t	2025-11-09 08:07:49.852807	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Prudential", "position": "Insurance Agent"}	2025-11-09 08:07:49.852807	2025-11-09 08:07:49.852807	evriean@gmail.com	601119881344	eva juan	\N
1990	9ee044d8-fc6c-4f9c-b5a6-58410e86759a	1	1	\N	Norhafiza Binti Umar	eiyja8714@gmail.com	60198585714	t	2025-11-09 08:08:07.873979	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "nzyumna", "position": "worker"}	2025-11-09 08:08:07.873979	2025-11-09 08:08:07.873979	eiyja8714@gmail.com	60198585714	norhafiza binti umar	\N
1991	cb723eff-19e2-4c0d-aeb9-7754d1d12b6d	1	1	\N	Asikin	asikinmusipar@yahoo.com.my	60135572039	t	2025-11-09 08:08:44.965778	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:08:44.965778	2025-11-09 08:08:44.965778	asikinmusipar@yahoo.com.my	60135572039	asikin	\N
1992	c252fdc2-347f-4674-9574-95d0d933ca96	1	1	\N	Ch Wong	bbhwang333@gmail.com	601133022368	t	2025-11-09 08:10:35.189907	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "F", "position": "R"}	2025-11-09 08:10:35.189907	2025-11-09 08:10:35.189907	bbhwang333@gmail.com	601133022368	ch wong	\N
1993	d1a81f70-1b84-4ce9-a357-0120ed620f61	1	1	\N	Alviin Ling	alviin_95@hotmail.com	60168109953	t	2025-11-09 08:10:50.327098	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:10:50.327098	2025-11-09 08:10:50.327098	alviin_95@hotmail.com	60168109953	alviin ling	\N
1994	ab4ee224-ee39-4d68-abc4-e00235c20c01	1	1	\N	Noorwahida Matnul	mhdazizn010901@gmail.com	60173837826	t	2025-11-09 08:15:45.303424	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:15:45.303424	2025-11-09 08:15:45.303424	mhdazizn010901@gmail.com	60173837826	noorwahida matnul	\N
1995	2398214e-36f8-4e40-9fb9-5f1fe73618b8	1	1	\N	Thooreq	tzieyaad@gmail.com	601137455990	t	2025-11-09 08:16:33.434273	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "The Pujaans", "position": "Manager"}	2025-11-09 08:16:33.434273	2025-11-09 08:16:33.434273	tzieyaad@gmail.com	601137455990	thooreq	\N
1996	ea515eaf-9055-49d9-bc7a-b222b21d27c9	1	1	\N	Arini Are	ariniarebintiabdgani@gmail.com	601136537033	t	2025-11-09 08:17:30.811148	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NHG Industries", "position": "Stock Controller"}	2025-11-09 08:17:30.811148	2025-11-09 08:17:30.811148	ariniarebintiabdgani@gmail.com	601136537033	arini are	\N
1997	72877e86-e956-41d1-9d8a-310a6cd40046	1	1	\N	Nurdin	kenedejawang@gmail.com	601126117731	t	2025-11-09 08:18:57.759643	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": ",", "position": ","}	2025-11-09 08:18:57.759643	2025-11-09 08:18:57.759643	kenedejawang@gmail.com	601126117731	nurdin	\N
1998	569047d4-831e-4d5d-8b5b-79cb37b63fe9	1	1	\N	Nurul	nurshahedatul1138@gmail.com	601111083229	t	2025-11-09 08:20:06.192801	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 08:20:06.192801	2025-11-09 08:20:06.192801	nurshahedatul1138@gmail.com	601111083229	nurul	\N
2001	a59737b4-3c4a-458c-b766-c47b8dcb456a	1	1	\N	Nazrienshah	narzwilliam@gmail.com	60142232268	t	2025-11-09 08:21:49.839406	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 08:21:49.839406	2025-11-09 08:21:49.839406	narzwilliam@gmail.com	60142232268	nazrienshah	\N
2002	ed3e9deb-2f30-499c-9e4b-79c1265746ba	1	1	\N	Roslianah Tining	leerose522@gmail.com	601121822774	t	2025-11-09 08:22:05.68423	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "NA", "position": "NA"}	2025-11-09 08:22:05.68423	2025-11-09 08:22:05.68423	leerose522@gmail.com	601121822774	roslianah tining	\N
2003	207d18bd-3b7f-4a1d-a1a3-9f063363db17	1	1	\N	William Ooi Hong Wee	William.axtrada@gmail.com	60122217160	t	2025-11-09 08:22:23.332315	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Axtrada Malaysia Sdn bhd", "position": "Managing Director"}	2025-11-09 08:22:23.332315	2025-11-09 08:22:23.332315	william.axtrada@gmail.com	60122217160	william ooi hong wee	\N
2004	c42a16df-b390-41d5-bb20-957991976cfd	1	1	\N	Kalsum	afika1238@gmail.com	60184605051	t	2025-11-09 08:26:16.77647	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "DELICHA", "position": "Staff"}	2025-11-09 08:26:16.77647	2025-11-09 08:26:16.77647	afika1238@gmail.com	60184605051	kalsum	\N
2005	26416bb4-7486-4f4a-b23b-1ac35df5f981	1	1	\N	Mohd Nur	afika1238@gmail.com	60162004912	t	2025-11-09 08:27:03.023048	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Delicha", "position": "Staff"}	2025-11-09 08:27:03.023048	2025-11-09 08:27:03.023048	afika1238@gmail.com	60162004912	mohd nur	\N
2009	d747ea1a-fa22-4c0f-88f0-f59cf447f070	1	1	\N	Cherry	syhrzhjmn95@gmail.com	601161185745	t	2025-11-09 08:36:34.380212	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:36:34.380212	2025-11-09 08:36:34.380212	syhrzhjmn95@gmail.com	601161185745	cherry	\N
2010	ed0b495a-56e7-4409-ba2c-e3d0ea0eb93c	1	1	\N	Yuna	Farah97@gmail.com	60178302230	t	2025-11-09 08:36:44.234295	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:36:44.234295	2025-11-09 08:36:44.234295	farah97@gmail.com	60178302230	yuna	\N
2011	85f7519b-9ea9-4c8c-8a82-293d8f0baf8c	1	1	\N	Cindy Khoo	Sintcindy@gmail.com	601159759028	t	2025-11-09 08:38:15.421016	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Emapta", "position": "Admin"}	2025-11-09 08:38:15.421016	2025-11-09 08:38:15.421016	sintcindy@gmail.com	601159759028	cindy khoo	\N
2012	b11caa38-fc23-4c93-bf3e-98bc757b2ac3	1	1	\N	Belaa	Belago@yahoo.com	60197501135	t	2025-11-09 08:40:24.686487	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Cheff eg", "position": "Staff"}	2025-11-09 08:40:24.686487	2025-11-09 08:40:24.686487	belago@yahoo.com	60197501135	belaa	\N
2013	4684c1c6-fff4-401c-ad64-c50c9b906ee4	1	1	\N	Sariah Sali	sariahsaliicha@gmail.com	601127598878	t	2025-11-09 08:40:27.675141	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "-", "position": "-"}	2025-11-09 08:40:27.675141	2025-11-09 08:40:27.675141	sariahsaliicha@gmail.com	601127598878	sariah sali	\N
2014	24dfa868-65b8-47b1-8c54-a38224ea53d7	1	1	\N	Jaswant	Jaswantgopal@gmail.com	60167532498	t	2025-11-09 08:41:11.136691	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "Sriwaras", "position": "Na"}	2025-11-09 08:41:11.136691	2025-11-09 08:41:11.136691	jaswantgopal@gmail.com	60167532498	jaswant	\N
2016	866b688f-4041-4e6f-a288-83d73be8e686	1	1	\N	Rachel	rouzi7933@gmail.com	60168257933	t	2025-11-09 08:46:13.680674	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "nil", "position": "nil"}	2025-11-09 08:46:13.680674	2025-11-09 08:46:13.680674	rouzi7933@gmail.com	60168257933	rachel	\N
2018	75dc2d68-6f6a-458e-9fc9-b526d7318f92	1	1	\N	Chu Vun Henn	vhchu1556@yahoo.com	60138830972	t	2025-11-09 09:30:50.585764	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "VHChu & Associates ", "position": "Managing Partner "}	2025-11-09 09:30:50.585764	2025-11-09 09:30:50.585764	vhchu1556@yahoo.com	60138830972	chu vun henn	\N
1267	f0bccb6e-2dcf-48de-ae21-80501feedff4	1	1	\N	Ann Chen	annchen.wsggroup@gmail.com	60128244933	t	2025-11-08 00:46:53.299686	\N	1	1	\N	\N	\N	{"role": "Visitor", "company": "WSG PROPERTIES SDN BHD", "position": "ACCOUNT ASSISTANT", "coupon_referral": "", "business_industry": "", "print_exhibitor_tag": ""}	2025-11-08 00:46:53.299686	2025-11-12 01:27:12.300864	annchen.wsggroup@gmail.com	60128244933	ann chen	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.users (id, email, password_digest, full_name, phone, role, created_at, updated_at, status, jti, email_verified_at, created_by_id) FROM stdin;
26	smexpo21@eventzflow.com	$2a$12$eS1DIGN9DNE1SyG6NOlTBOCo9LJe8y.DW3muiXMKYEX7joHdHhxr2	SME Expo Staff 21	\N	2	2025-11-05 02:51:10.904848	2025-11-08 04:41:00.606827	1	4a246e3d-bcb7-4b15-9263-a8cb12403a1c	2025-11-05 02:52:57.10088	\N
29	smexpo31@eventzflow.com	$2a$12$oIXBWI6XxuTK4RQ7FMTnaOD.JNY4jmUWDnFf0BBZ4M1KWxszbwv9W	SME Expo Staff 21	\N	2	2025-11-05 02:52:31.209952	2025-11-08 05:25:18.045583	1	af6b44e3-17b0-4f62-a50b-988cbc9309a5	2025-11-05 02:52:57.10088	\N
23	smexpo11@eventzflow.com	$2a$12$EWtKKAvsRbSTnw43MT12IeyzC.EO4czBHad4MK9J/DGwrRpGQsVDu	SME Expo Staff 11	\N	2	2025-11-05 02:48:50.466519	2025-11-20 12:57:03.269204	1	bc6687eb-9294-4349-9f5d-1acd81fefe54	2025-11-05 02:50:07.078494	\N
33	vendorex@example.com	$2a$12$VF5cCz8AH5ultU8FalZnsehmrXsDBHAnO8p39FHvAxhXU5206LIa.	Vendor Example	1234567890	3	2025-11-25 05:11:47.600243	2025-11-25 05:39:09.285557	1	171ffb5e-1e45-4b5c-b120-8baf7bb263a2	2025-11-25 05:11:47.371544	10
11	manager_1@example.com	$2a$12$Wns4GVDi/ICVrWvMnsDUF.FLUG49q1b1ATEmjvgdbvCaIFfxs/k/i	Kathyrn Howe (Manager 1)	\N	1	2025-10-28 02:10:08.442112	2025-10-28 02:10:08.442112	1	5d7caeac-3d4d-4424-961b-d58fed5d48fc	2025-10-28 02:10:08.647	\N
35	vendororg@example.com	$2a$12$fqVMm53tn3w7lK9ONU3/geLr073kdMwJtIkXqHlU5mNmx7SBWRDxu	Vendor Org	1234567890	3	2025-11-25 05:38:13.14708	2025-11-25 05:38:13.14708	1	fccfb944-de72-44c2-a46e-4b9063d4d0a3	2025-11-25 05:38:12.935911	34
34	orgex@example.com	$2a$12$zes3lMVi3WNSOPp3OenHAuWwoyMD7x4dgoTMTbqze/dcjuiRyULzO	Organizer Example	1234567890	1	2025-11-25 05:35:07.809625	2025-11-25 05:49:18.433521	1	92aafd2c-ac4d-40a3-8e9b-f85073b0229d	2025-11-25 05:11:47.371544	10
36	hq@pumm.my	$2a$12$6demnz0psjv0u0JExj0PguBEMH0AmYW01QfRza9UK2nuuKj5m9CbC	PUMM HQ	\N	2	2025-11-28 02:15:25.041249	2025-11-28 02:15:25.041249	1	e81b07cb-8239-40f5-8195-746b03b5621f	2025-11-28 02:19:42.219147	10
22	orson.t99@gmail.com	$2a$12$jWm8w83CyTEFDMl6RlRkwezCPEh00fDtSzzHBEgirrH4XHfCHtY0u	Son Test	+60148516962	2	2025-10-28 05:01:43.329933	2025-10-29 05:56:15.128546	1	7504b118-5f5d-43f5-911b-1257279e3aa2	2025-10-29 05:54:47.852211	\N
37	malacca@pumm.my	$2a$12$kqg.HYNGRGVfTIdEWOwxDuwsC2bw7CbqTtZdH4bP.LEg0dEi5hCOu	PUMM Malacca	\N	2	2025-11-28 02:20:39.478131	2025-11-28 02:20:39.478131	1	33bd9049-f44c-4a90-988e-3903c22bf055	2025-11-28 02:21:32.946548	10
10	s@s.com	$2a$12$bS4Uy0bZOR8UC32j5uKyFOV7sIsA/BS8/cUsn8q8kFz/nxVUwEHOu	EventzFlow Admin	\N	0	2025-10-28 02:10:07.728384	2025-11-28 10:26:54.086239	1	ab232720-16a9-4a76-b7b5-2261a532272b	2025-10-28 02:31:22.307	\N
12	manager_2@example.com	$2a$12$TSKSQcLEyhepr51Or5MyMeoJybGEATqupxvVuhN4Ayr8u5EEznO02	Fr. Gianna Kuhn (Manager 2)	\N	1	2025-10-28 02:10:08.649342	2025-10-28 02:10:08.649342	1	57459a24-4ceb-49aa-b61b-85f21989aed6	2025-10-28 02:10:08.647479	\N
13	manager_3@example.com	$2a$12$wkZKx7NEWg25BLrq8Q30CeO1IWAI59SalQxmKtbwFJ9DpSCDTOWJW	Tierra Harris (Manager 3)	\N	1	2025-10-28 02:10:08.854829	2025-10-28 02:10:08.854829	1	19c5d92c-31bd-4f4d-8e17-9a420812d4ac	2025-10-28 02:10:08.852633	\N
38	admin2@eventzflow.com	$2a$12$s1q2zePIsj4OyNQi/ffppu8VtRC/zHmFc8v6MhvNaQKlBq8k3w97y	Admin 2	0123456789	0	2025-12-02 02:41:15.091321	2025-12-02 02:41:22.644621	1	ba9a6f55-c77b-4bc8-a7f0-78ad4b9d1f8c	2025-11-25 05:11:47.371544	\N
17	unauthorized@example.com	$2a$12$XJ3VbJ4Wj/kZsFbmYFFBN./y81BYIa.5cS5DZSJuDIziWW1oJp30K	Unauthorized Member	\N	2	2025-10-28 02:10:09.692538	2025-10-28 02:10:09.692538	1	b58e08ee-0bc8-426d-b636-baad006d6d72	2025-10-28 02:10:09.690018	\N
18	participant@example.com	$2a$12$mivyho2PCRdyJkyMaCLz0eYGbZV/VnccM0yNwLJiFMmz28m0PKwiC	Sarah Ticket Holder	\N	2	2025-10-28 02:10:09.90198	2025-10-28 02:10:09.90198	1	b5b0cd2f-7b36-48a5-98d3-f0788dfeb3eb	2025-10-28 02:10:09.899818	\N
21	brown.gamingz12@gmail.com	$2a$12$hMs1AQEwmVtzbMhoesPT0uqOnUeihrgO4m1dbP81WkJS9SWRDgjYW	Nurahfezan Bin Nordin	0172899043	2	2025-10-28 02:11:37.470627	2025-10-28 02:11:37.470627	1	34d68152-c218-42b4-9a53-8e905ffe92d7	\N	\N
20	marsh.playz32@gmail.com	$2a$12$4rr0o21UYPYbE/WkBEqhx.NtqME1AUULyqAnflziVwsqEsJLnIKsW	Nurahfezan Bin Nordin	0172899043	2	2025-10-28 02:11:18.750731	2025-10-28 03:19:48.753901	1	a21ee990-001b-4b9e-a476-2545f2594eab	2025-10-28 02:31:22.307286	\N
19	nurahfezanbinnordin@gmail.com	$2a$12$3SKt.rLf5pJ92mrG1C0yoeTyCzbksBsURLpjfI7Dky2VDHLA8Jpo6	Nurahfezan Bin Nordin	0172899043	2	2025-10-28 02:10:40.388391	2025-10-30 02:06:38.668653	1	9a1e4f29-210e-4cde-ad1c-8fd4e764b8bb	\N	\N
27	smexpo22@eventzflow.com	$2a$12$t1NrLNI8S6p5QPAS15RaYue6KisBA1Qi5lJ0mxQPCqXv2wkDWxrXi	SME Expo Staff 22	\N	2	2025-11-05 02:51:53.107506	2025-11-05 11:14:39.057792	1	8696aa2a-4b82-467d-9ef8-c538d95b5220	2025-11-05 02:52:57.10088	\N
25	smexpo13@eventzflow.com	$2a$12$5.G1x.kw1dEjZvc5riAy..TzaqDV2vkxVVc0PzfzWCNzvlxkgXOZe	SME Expo Staff 13	\N	2	2025-11-05 02:50:17.549264	2025-11-07 02:32:40.35296	1	bc12f792-61e2-4f87-b856-fab8f11dbf47	2025-11-05 02:50:35.286563	\N
31	smexpo33@eventzflow.com	$2a$12$OhsoBJ8wM87Oeq/sUGqwE.R22ffE7.y3Gbpbl9aLOyQoa9/BUdDKu	SME Expo Staff 33	\N	2	2025-11-05 02:53:12.01786	2025-11-05 02:53:12.01786	1	1c469e07-3e77-4947-97a0-ee7d9de01cc5	2025-11-05 02:53:20.465435	\N
28	smexpo23@eventzflow.com	$2a$12$gCojfRLdf8wY9n5P3iAec.rAhg3ZfHrM0YpjVNJxgATm2f6GChA.e	SME Expo Staff 23	\N	2	2025-11-05 02:52:12.364382	2025-11-05 10:38:37.287026	1	cb39798e-a746-4cb6-b438-0a3b59ac7448	2025-11-05 02:52:57.10088	\N
32	sandy.aichang@gmail.com	$2a$12$TndX8PgPVp4YnD6nI8pvMeelH7hL7qVlxS9RoDPOHoN0h4gDPPcFi	Sandy Chen	016-804 3439	2	2025-11-06 23:51:17.688172	2025-11-06 23:51:38.56492	1	9ab8aad5-1e93-421e-9144-34a93a44324b	2025-11-06 23:51:38.562251	\N
24	smexpo12@eventzflow.com	$2a$12$lkBMOtmdCgKryZ803.jm8O0v8dJmmLCjTaSegIz6KZKM5YQl93Yyy	SME Expo Staff 12	\N	2	2025-11-05 02:49:59.687915	2025-11-07 03:09:30.287594	1	d22da800-66e9-44b4-a86a-20fbc73051dc	2025-11-05 02:50:17.818199	\N
30	smexpo32@eventzflow.com	$2a$12$PbSgwMugRCZ6lFn51xVwy.9WdJkelKuQ.GLRC/U6WZt8fKnzP.6Om	SME Expo Staff 32	\N	2	2025-11-05 02:52:51.096906	2025-11-07 04:59:36.519002	1	be893435-253e-4c5f-a41d-af3c8d576862	2025-11-05 02:53:13.222008	\N
\.


--
-- Data for Name: vendor_profiles; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.vendor_profiles (id, vendor_id, image_path, description, created_at, updated_at, category, person_in_charge, address, notes) FROM stdin;
1	33	\N	\N	2025-11-25 05:11:47.626071	2025-11-25 05:11:47.626071	\N	\N	\N	\N
2	35	\N	\N	2025-11-25 05:38:13.150647	2025-11-25 05:38:13.150647	\N	\N	\N	\N
\.


--
-- Data for Name: visitor_vendor_stamps; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.visitor_vendor_stamps (id, visitor_id, event_vendor_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: visitors; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.visitors (id, event_id, public_id, full_name, gender, age, phone, email, created_at, updated_at) FROM stdin;
1	2	287154f8-da95-41eb-89c0-bce1b5d61e6b	Fish Tan	\N	\N	601110949481	\N	2025-11-28 04:37:54.498899	2025-11-28 04:37:54.498899
2	2	37057e7a-2fc2-4ac6-97bf-74e6b09f8a0f	Shion Lee Ns	\N	\N	60123728628	\N	2025-11-28 06:05:41.914401	2025-11-28 06:05:41.914401
3	2	1ba95ba5-44b6-41be-a78b-a86b94358893	Rexx Law	\N	\N	60122866834	\N	2025-11-28 11:19:28.135787	2025-11-28 11:19:28.135787
4	2	998e258e-bf93-4307-98e5-de6185f9cfcb	Bryan Kok	\N	\N	60146589902	\N	2025-11-28 11:19:34.594723	2025-11-28 11:19:34.594723
5	2	35a97372-4817-4b78-9a22-65cadb1cc305	Wenxy Chong	\N	\N	60169227027	\N	2025-11-28 11:19:38.729949	2025-11-28 11:19:38.729949
6	2	c863a3da-37c9-4117-9950-0511cb2a39d7	Henry Yeoh Eng	\N	\N	60124808708	\N	2025-11-28 11:19:41.079728	2025-11-28 11:19:41.079728
7	2	1559a163-7c09-4b14-a506-9c60f3b296f2	Tan Sho Pei	\N	\N	60124332829	\N	2025-11-28 11:19:47.617956	2025-11-28 11:19:47.617956
8	2	04e456a8-05fe-4a79-95de-96a039d7626f	Yee Wen Xuen	\N	\N	60182414368	\N	2025-11-28 11:19:53.01501	2025-11-28 11:19:53.01501
9	2	9fefaa08-e316-423a-bae0-6d486103c5a1	Lim Shu Ning	\N	\N	60134501000	\N	2025-11-28 11:19:53.768682	2025-11-28 11:19:53.768682
10	2	cbf96efe-fc93-4d70-8459-fc090b82f1b9	Tan Yuen Chung	\N	\N	60122812677	\N	2025-11-28 11:19:54.464452	2025-11-28 11:19:54.464452
11	2	eea123ce-3669-4b16-84b3-31e512d0eea7	Wong Chin Pong	\N	\N	60169838439	\N	2025-11-28 11:19:54.623562	2025-11-28 11:19:54.623562
12	2	d283aa70-81f4-4474-9215-4bd38dfc7651	Kengy	\N	\N	60166382939	\N	2025-11-28 11:19:54.731793	2025-11-28 11:19:54.731793
13	2	0039b2c2-ba7f-4faf-b88b-580ec4970bfa	Tan Wei Jie	\N	\N	601136806818	\N	2025-11-28 11:19:55.782296	2025-11-28 11:19:55.782296
14	2	38595d75-d5d4-441a-aa92-a222478e5bd2	Go Chia Yoong	\N	\N	60134545824	\N	2025-11-28 11:19:59.35241	2025-11-28 11:19:59.35241
15	2	fdc9d4fb-a659-4772-9a86-e8920362c17d	Tieu Siak Kia	\N	\N	60143254231	\N	2025-11-28 11:20:01.379838	2025-11-28 11:20:01.379838
16	2	65d682a8-df1b-44b0-a08f-bb8b1fe1e81d	Lim Eng Yiu	\N	\N	60162860195	\N	2025-11-28 11:20:01.822262	2025-11-28 11:20:01.822262
17	2	0fcd9641-9129-4bfb-9494-bccc217b0caf	Penny Leong	\N	\N	60176954087	\N	2025-11-28 11:20:03.561022	2025-11-28 11:20:03.561022
18	2	55395b17-8c16-4766-84e7-e583fb419e7c	Wong Yee Shu	\N	\N	60167126911	\N	2025-11-28 11:20:04.076104	2025-11-28 11:20:04.076104
19	2	7b25cc51-490b-4f23-b55e-8e6efbd56997	Lee Mun You	\N	\N	601155060342	\N	2025-11-28 11:20:04.58972	2025-11-28 11:20:04.58972
20	2	ee4dc0c3-fae2-4df2-b962-de7d0b2cd9b5	Nicole Wong Ing Lin	\N	\N	60128871308	\N	2025-11-28 11:20:04.628716	2025-11-28 11:20:04.628716
21	2	b404c670-8861-4ade-9c70-f6f7717d2ba8	Dato Dr Ricky Tan	\N	\N	60123259822	\N	2025-11-28 11:20:04.757168	2025-11-28 11:20:04.757168
22	2	c1e7c833-c667-4350-8f80-f67ca7faa5f7	Su Chung Sheng	\N	\N	60125641319	\N	2025-11-28 11:20:05.847458	2025-11-28 11:20:05.847458
23	2	016d456d-7fc1-4754-8693-15aa83ca70a6	Choo Jia Hong	\N	\N	60167007722	\N	2025-11-28 11:20:06.472537	2025-11-28 11:20:06.472537
24	2	501a62d5-6c7b-4214-b4c8-726d6e2ff93a	Chia Wei Jie	\N	\N	60149444048	\N	2025-11-28 11:20:06.57543	2025-11-28 11:20:06.57543
25	2	6aeda6b8-be24-40a1-ad9b-b5a8680d0048	Jynn	\N	\N	60182536090	\N	2025-11-28 11:20:07.791748	2025-11-28 11:20:07.791748
26	2	0d7caf65-b041-4af1-8340-ac842794b060	Leow Chuen Kiat	\N	\N	60176708893	\N	2025-11-28 11:20:08.423857	2025-11-28 11:20:08.423857
27	2	26b6b16a-18e4-461b-9985-d75622e0922c	Fabian Hoong	\N	\N	60122078783	\N	2025-11-28 11:20:08.756257	2025-11-28 11:20:08.756257
28	2	d4b635af-2246-47d0-819d-14d7b25167d1	Liew Wei Lun	\N	\N	60172296491	\N	2025-11-28 11:20:08.771059	2025-11-28 11:20:08.771059
29	2	6d5c0f83-e65c-4159-ab44-576b27fa0c04	Albert Tan Wee Siong	\N	\N	60127553203	\N	2025-11-28 11:20:09.614535	2025-11-28 11:20:09.614535
30	2	0ff52901-ffff-4c46-9e17-5189ec6a6c26	Anthony Low Chun Hong	\N	\N	60162079796	\N	2025-11-28 11:20:10.115753	2025-11-28 11:20:10.115753
31	2	3f629bb5-f663-4869-aa52-6b15c4021e2a	Edmund Tham	\N	\N	60123166995	\N	2025-11-28 11:20:10.337058	2025-11-28 11:20:10.337058
32	2	90f55944-e581-4a8b-939c-a7a118454b7f	Law Yong Ming	\N	\N	60122919214	\N	2025-11-28 11:20:11.232268	2025-11-28 11:20:11.232268
33	2	a8cc0e9e-c76b-4d45-8278-57a7b037913d	Ryan Ng	\N	\N	60175805057	\N	2025-11-28 11:20:11.939489	2025-11-28 11:20:11.939489
34	2	6026f5e5-3dd9-4d63-9e76-8654a549ba98	Howard Yap	\N	\N	60149346272	\N	2025-11-28 11:20:12.708186	2025-11-28 11:20:12.708186
35	2	e8e5b4d6-325e-4a55-92bb-bd325cd1a3af	Lawrence Choong	\N	\N	60122790663	\N	2025-11-28 11:20:13.597267	2025-11-28 11:20:13.597267
36	2	9a6faf4f-6f37-461b-82dd-7343d6dc36b4	Tan Jack Leang	\N	\N	601114872688	\N	2025-11-28 11:20:14.22605	2025-11-28 11:20:14.22605
37	2	fd039c92-5a29-4cec-8b3f-2acd544c4bf5	Vickey Tye	\N	\N	60169031977	\N	2025-11-28 11:20:14.394929	2025-11-28 11:20:14.394929
38	2	81bdfb4c-bbf9-4ad0-ab36-61552b96157d	Helen Choo	\N	\N	60124753875	\N	2025-11-28 11:20:14.689862	2025-11-28 11:20:14.689862
39	2	1e841ee6-b423-415b-8a9d-c06b8d8a7346	Pey Ying Qi	\N	\N	60125055329	\N	2025-11-28 11:20:14.961236	2025-11-28 11:20:14.961236
40	2	9703c191-32bc-450a-979e-d3af93d74215	Ng Li Hong	\N	\N	60127085090	\N	2025-11-28 11:20:19.268293	2025-11-28 11:20:19.268293
41	2	5c236093-9da6-4ff5-a093-46c68e7f1ed4	Loh Chai Chen	\N	\N	60169522909	\N	2025-11-28 11:20:21.33384	2025-11-28 11:20:21.33384
42	2	10b53e64-9790-4037-81f2-52e25dcc0ed7	Sw Khor Yi	\N	\N	60149438762	\N	2025-11-28 11:20:22.60556	2025-11-28 11:20:22.60556
43	2	3c0c2244-d684-4ce4-9c3c-effca8123324	Tan Chun Siong	\N	\N	60165593785	\N	2025-11-28 11:20:23.474815	2025-11-28 11:20:23.474815
44	2	187353d5-0229-4d2d-9bc3-9c5cb84dc1c8	Jenson Lai	\N	\N	60122097797	\N	2025-11-28 11:20:24.950683	2025-11-28 11:20:24.950683
45	2	3e0ccb90-a794-4863-873f-be5bb1f55e4d	Jin Koh	\N	\N	60166160216	\N	2025-11-28 11:20:25.669388	2025-11-28 11:20:25.669388
46	2	a29259b0-142a-4aa7-8712-502972dfb974	Cindy Ng Chow Li	\N	\N	60123459633	\N	2025-11-28 11:20:26.413165	2025-11-28 11:20:26.413165
47	2	b5fb5dce-fc27-43d1-b35c-6b41578245fc	Chu Vui Yen	\N	\N	60168398369	\N	2025-11-28 11:20:27.579879	2025-11-28 11:20:27.579879
48	2	7330a40f-85d5-4bf9-8a22-1878f6098337	Lim Kok Seong	\N	\N	60166680938	\N	2025-11-28 11:20:27.724423	2025-11-28 11:20:27.724423
49	2	566d115c-706f-4c90-96a2-fc34c3a556fd	Liew Siew Yee	\N	\N	60196684768	\N	2025-11-28 11:20:27.794091	2025-11-28 11:20:27.794091
50	2	d613147d-7a87-4aa5-b436-2f2cf286c497	Li Zheng Han	\N	\N	60162893665	\N	2025-11-28 11:20:28.149505	2025-11-28 11:20:28.149505
51	2	05c7531f-6b17-4a8a-b5b9-9bc9d1422e04	Limsan	\N	\N	60197733627	\N	2025-11-28 11:20:28.787198	2025-11-28 11:20:28.787198
52	2	721d0e7a-a5e7-4e51-81d2-8bf3281a337c	Ng Cheng Heng	\N	\N	60127733272	\N	2025-11-28 11:20:29.71079	2025-11-28 11:20:29.71079
53	2	3b224e4f-5913-4e25-855b-5fc93e0cabcf	See Qin Yee	\N	\N	886938713873	\N	2025-11-28 11:20:30.822934	2025-11-28 11:20:30.822934
54	2	5862053d-99f5-4929-b03a-6123a8bec6fa	Chris Pang Min Quan	\N	\N	60122168431	\N	2025-11-28 11:20:31.107297	2025-11-28 11:20:31.107297
55	2	844f2fef-8ac2-4b23-a392-a79f4eccf5fc	Tye Kok Hao	\N	\N	601133003161	\N	2025-11-28 11:20:31.605537	2025-11-28 11:20:31.605537
56	2	6d73129c-6b6c-49be-981a-35733ceea6b8	Hao Xiang	\N	\N	601139105675	\N	2025-11-28 11:20:31.657004	2025-11-28 11:20:31.657004
57	2	9f229fa4-7a40-4e21-b6c1-baea02aa1af8	Jojo	\N	\N	60173500128	\N	2025-11-28 11:20:31.918447	2025-11-28 11:20:31.918447
58	2	e1bf78ea-7cea-4050-acf6-3d33e4b14035	Sow Meng Khiang	\N	\N	60122002968	\N	2025-11-28 11:20:33.082967	2025-11-28 11:20:33.082967
59	2	c742dcb0-6987-4500-846d-8f680104f991	Foo Chei Chei	\N	\N	60163399029	\N	2025-11-28 11:20:33.35648	2025-11-28 11:20:33.35648
60	2	3058915f-66c7-40be-86fb-356f1d745365	Caren Low	\N	\N	60128688625	\N	2025-11-28 11:20:34.659483	2025-11-28 11:20:34.659483
61	2	23cb8f12-ec00-487b-b568-339fde80cff9	Yeoh Sian Wei	\N	\N	60189742338	\N	2025-11-28 11:20:35.527702	2025-11-28 11:20:35.527702
62	2	7b500cdf-576b-447a-865e-463a95c97bbf	Keaton Chew	\N	\N	60149256733	\N	2025-11-28 11:20:36.643204	2025-11-28 11:20:36.643204
63	2	0839bc4b-7087-4350-a5f9-e83bad0dd391	Cassey Tan	\N	\N	60145575208	\N	2025-11-28 11:20:37.66309	2025-11-28 11:20:37.66309
64	2	9a2cf4e3-5809-4799-8422-d4c7dfb88f1f	Eric Foo	\N	\N	60122268086	\N	2025-11-28 11:20:38.29425	2025-11-28 11:20:38.29425
65	2	5fa9e2b5-e939-4f75-accb-118b5c6e9d30	Ng Weng Kee	\N	\N	60182267822	\N	2025-11-28 11:20:38.511748	2025-11-28 11:20:38.511748
66	2	11d1e48d-df65-480a-9a8e-98453e6d6b15	Tan Choon Ping	\N	\N	60125862316	\N	2025-11-28 11:20:38.691261	2025-11-28 11:20:38.691261
67	2	8077dd2d-343d-4388-8abe-d7ba103546e0	Ong Xiao Wern	\N	\N	60129629829	\N	2025-11-28 11:20:40.211138	2025-11-28 11:20:40.211138
68	2	0739583a-45ca-4d86-837d-2bf05f50f98c	Mohd Faisal Bin Abdullah Bada	\N	\N	60173840394	\N	2025-11-28 11:20:40.867726	2025-11-28 11:20:40.867726
69	2	466ee425-0acd-4d1a-a91e-84f23de69d56	Joyce Lee Yin Min	\N	\N	60163238560	\N	2025-11-28 11:20:41.818002	2025-11-28 11:20:41.818002
70	2	0542cc1e-374e-4064-a237-ea37b59e143a	Liew Choon Kit	\N	\N	60126176707	\N	2025-11-28 11:20:42.765886	2025-11-28 11:20:42.765886
71	2	6d9ed130-8422-47c4-9e82-9bb330b9e396	Khaw Veon Su	\N	\N	60124386300	\N	2025-11-28 11:20:43.010685	2025-11-28 11:20:43.010685
72	2	7cbc9903-0b65-467b-99c8-609b98e5b0af	Alvin Soh	\N	\N	60126139081	\N	2025-11-28 11:20:43.785056	2025-11-28 11:20:43.785056
73	2	74c7012a-00dc-4f2b-a699-f94a7aa064e9	Poo Ching Loong	\N	\N	60172232288	\N	2025-11-28 11:20:43.832828	2025-11-28 11:20:43.832828
74	2	ce150c91-318e-4822-af79-2e1dcd237508	Muhammad Danialhafiz Bin Abdul Halim	\N	\N	60174546870	\N	2025-11-28 11:20:44.522841	2025-11-28 11:20:44.522841
75	2	d4855968-b75c-4bf9-be13-7be2321328cd	Yap Xiao Yan	\N	\N	60162389984	\N	2025-11-28 11:20:44.67174	2025-11-28 11:20:44.67174
76	2	4162888f-239f-4670-b256-e74d969dafa7	Lee Boon Hoe	\N	\N	60122159897	\N	2025-11-28 11:20:44.825662	2025-11-28 11:20:44.825662
77	2	7f0abea8-8471-438d-b821-30422d06c6f7	Jiahe Khoo	\N	\N	60169061240	\N	2025-11-28 11:20:45.00001	2025-11-28 11:20:45.00001
78	2	d326126e-10b9-4ff4-b794-e36a63dc2af4	Jane Ong	\N	\N	60197335137	\N	2025-11-28 11:20:45.407298	2025-11-28 11:20:45.407298
79	2	e89d43ad-3809-42c2-bd6b-7b35ebc2a29c	Ally Chai	\N	\N	60109781735	\N	2025-11-28 11:20:45.520835	2025-11-28 11:20:45.520835
80	2	42c2e5c5-e270-4f8a-b093-8e5dbcd0c1b6	Cindy Tan Sin-ee	\N	\N	60123746383	\N	2025-11-28 11:20:46.655757	2025-11-28 11:20:46.655757
81	2	1e33e8b4-dd91-452b-97ca-0ef67f43a0f1	Ricky Lian	\N	\N	60126188719	\N	2025-11-28 11:20:49.24377	2025-11-28 11:20:49.24377
82	2	0f7f4431-ee26-49c3-9965-81ce59fd8edc	Andrew Goh Chee Tha	\N	\N	60125208019	\N	2025-11-28 11:20:49.732876	2025-11-28 11:20:49.732876
83	2	4ab13024-ff46-47f1-94ce-113a69f097da	Shaney Chuah	\N	\N	60126545392	\N	2025-11-28 11:20:50.786473	2025-11-28 11:20:50.786473
84	2	86f2d0b7-35c7-4c5b-b37d-9b76c7ba7029	Tan Kwong Wei	\N	\N	60149312508	\N	2025-11-28 11:20:50.827784	2025-11-28 11:20:50.827784
85	2	7022a2ce-d9b0-4276-b35a-c11a6bbd1eeb	David Alan Bates	\N	\N	60122023895	\N	2025-11-28 11:20:51.488621	2025-11-28 11:20:51.488621
86	2	a93ad627-9a86-4861-8db2-e7615c753cf0	Gan Whei Chee	\N	\N	60129185668	\N	2025-11-28 11:20:51.801518	2025-11-28 11:20:51.801518
87	2	0ba28b31-2c5e-4df9-a718-fd144ca796c8	Anne Gan	\N	\N	60162799286	\N	2025-11-28 11:20:52.37755	2025-11-28 11:20:52.37755
88	2	56cf01e2-f249-45a0-a074-c522ac49232c	Hugo	\N	\N	60102323110	\N	2025-11-28 11:20:52.472741	2025-11-28 11:20:52.472741
89	2	5ef3629a-d508-46fe-bb30-4db9c70a2cdb	Poa Siew Nan	\N	\N	60163152698	\N	2025-11-28 11:20:53.179625	2025-11-28 11:20:53.179625
90	2	208204cc-f48d-4b8d-92c3-b9920dfa565f	Lee Jia Chiang	\N	\N	60146480152	\N	2025-11-28 11:20:53.570309	2025-11-28 11:20:53.570309
91	2	0b2f4247-7ff3-4d71-ada0-aae0ddcd8b04	Wong Zhen Peng	\N	\N	60102732290	\N	2025-11-28 11:20:54.152915	2025-11-28 11:20:54.152915
92	2	242dac5d-5548-4982-a8f2-e51715fe1c98	Kelvin Wong Kar Zhuen	\N	\N	60127331099	\N	2025-11-28 11:20:54.478603	2025-11-28 11:20:54.478603
93	2	a4c2a704-89a5-42a6-8292-e4e53e5456f5	Lim Zhi Bin	\N	\N	60164222131	\N	2025-11-28 11:20:54.812869	2025-11-28 11:20:54.812869
94	2	0ff8adfd-8d8c-48bc-a989-aad7f235e000	Kok Wee Yunn	\N	\N	60123528679	\N	2025-11-28 11:20:54.841245	2025-11-28 11:20:54.841245
95	2	157f1419-ab58-4bd7-9706-646cccc86093	Chinsoon Yee	\N	\N	60122783747	\N	2025-11-28 11:20:55.513712	2025-11-28 11:20:55.513712
96	2	55ba9478-dd6a-4afb-9cc8-d85475b5b46f	Tee Hui Suen	\N	\N	60163073011	\N	2025-11-28 11:20:55.713676	2025-11-28 11:20:55.713676
97	2	7d9f7a46-ab08-476a-9291-7b82925f1546	Chang Pei Thing	\N	\N	60177411978	\N	2025-11-28 11:20:55.824109	2025-11-28 11:20:55.824109
98	2	fcc1a716-6f9f-467a-891f-f21723f6f83d	Koh Shu Ting	\N	\N	60167358862	\N	2025-11-28 11:20:56.245263	2025-11-28 11:20:56.245263
99	2	d1b87cfe-d940-4443-8bba-ca24b0cfee96	Ivor Gan Kee Hao	\N	\N	60169387819	\N	2025-11-28 11:20:57.387855	2025-11-28 11:20:57.387855
100	2	11c61d02-746d-43c0-8aad-d42e649a9d19	Jason Lew	\N	\N	60162273186	\N	2025-11-28 11:20:58.813789	2025-11-28 11:20:58.813789
101	2	9d16993a-0f38-47cc-932a-5f4c61923979	Lim Chia Jin	\N	\N	60166832470	\N	2025-11-28 11:20:59.414924	2025-11-28 11:20:59.414924
102	2	dce13a8e-8227-4712-9576-1d1291f868f8	Ong Shu Yuen	\N	\N	60123038522	\N	2025-11-28 11:20:59.764482	2025-11-28 11:20:59.764482
103	2	f9361155-79b6-4510-b1cb-b5ba6ad0bc48	Yeow Chu Pei	\N	\N	601163594134	\N	2025-11-28 11:20:59.802588	2025-11-28 11:20:59.802588
104	2	3eb08f4a-5e1f-4505-9e3d-96b9cdae4fbb	Lim Shu Wei	\N	\N	60104048888	\N	2025-11-28 11:21:00.089533	2025-11-28 11:21:00.089533
105	2	c691cd9a-2546-413a-a28a-444dd76c0346	Chai Charng Kean	\N	\N	60125760660	\N	2025-11-28 11:21:00.914367	2025-11-28 11:21:00.914367
106	2	611bbb58-c493-485d-b0b5-c9984e18a8a0	Koh Siew Mei	\N	\N	60122697777	\N	2025-11-28 11:21:02.565983	2025-11-28 11:21:02.565983
107	2	1e8106a1-fa86-4a6a-a3aa-1a9bb3297a2a	Candy Tan	\N	\N	60187747649	\N	2025-11-28 11:21:02.620304	2025-11-28 11:21:02.620304
108	2	b00a3d39-ec25-4b82-847b-8d1d854eb252	Teh Tai Sheng	\N	\N	60199801337	\N	2025-11-28 11:21:02.975295	2025-11-28 11:21:02.975295
109	2	9c12a37e-24c1-4b44-835b-c0be65837335	Anne Law	\N	\N	60102713827	\N	2025-11-28 11:21:03.482044	2025-11-28 11:21:03.482044
110	2	3704fad4-0a67-4974-9e0c-cd59a4ba1280	Lee Jia Jun	\N	\N	60197784773	\N	2025-11-28 11:21:05.052323	2025-11-28 11:21:05.052323
111	2	73a2bff3-df12-46d9-bd11-b5f793880974	Chan Choi Hong	\N	\N	601121918192	\N	2025-11-28 11:21:05.11899	2025-11-28 11:21:05.11899
112	2	4dead365-dff8-4c5f-b68d-b8a232d5bc7d	Lai Jenn Wuu	\N	\N	60192921613	\N	2025-11-28 11:21:06.172316	2025-11-28 11:21:06.172316
113	2	72019b06-391a-4da4-be25-d4ae640978e5	Lee Yi Ching	\N	\N	60127827969	\N	2025-11-28 11:21:06.372287	2025-11-28 11:21:06.372287
114	2	e2544dc2-6987-4191-bc4b-91e0f14d874d	Ng Yong Quan	\N	\N	60139821319	\N	2025-11-28 11:21:07.258724	2025-11-28 11:21:07.258724
115	2	53e6af79-c1b3-4929-84b2-91ee259f6442	Ngo Swee Goh	\N	\N	60198817707	\N	2025-11-28 11:21:07.694584	2025-11-28 11:21:07.694584
116	2	de327592-dfb9-41c3-86bc-2035314f11ca	Chen Kok Bin	\N	\N	60143630863	\N	2025-11-28 11:21:08.356959	2025-11-28 11:21:08.356959
117	2	43fb7712-0d9b-4487-80f4-c290d42db004	Gan Fei Wei	\N	\N	60174412032	\N	2025-11-28 11:21:08.992729	2025-11-28 11:21:08.992729
118	2	06cec29f-06cc-4d57-8950-5fa9059a49d1	Le Hoang Anh	\N	\N	60125693613	\N	2025-11-28 11:21:09.895535	2025-11-28 11:21:09.895535
119	2	b4bdc2d4-3b31-425d-99d3-ea37405082c4	Syafiah Naimah Samsuddin	\N	\N	60104005105	\N	2025-11-28 11:21:10.950769	2025-11-28 11:21:10.950769
120	2	329144ec-fd36-4f33-80de-feb2fa10baad	Tan Xuan Zhu	\N	\N	601126100925	\N	2025-11-28 11:21:11.606519	2025-11-28 11:21:11.606519
121	2	25b8e49e-cd18-48da-b477-d2969cca70b1	Ng Poh Lean	\N	\N	60126682862	\N	2025-11-28 11:21:12.046621	2025-11-28 11:21:12.046621
122	2	898d025c-d3a7-435a-8e8c-e546be32e129	Lim Li Heng	\N	\N	60197529978	\N	2025-11-28 11:21:12.76648	2025-11-28 11:21:12.76648
123	2	208e4845-65a9-4d36-a1a3-00e97b218958	Sally Tong Yee Shu	\N	\N	60167542899	\N	2025-11-28 11:21:14.118862	2025-11-28 11:21:14.118862
124	2	668831e9-4f8e-478f-870d-b8ab1b5366ae	Wilson Choo	\N	\N	60166089916	\N	2025-11-28 11:21:14.253585	2025-11-28 11:21:14.253585
125	2	c8b6f869-fb33-491b-9226-2022db970ed7	Nurul Nasyitah Binti Mohamed Zainuddin	\N	\N	60199248728	\N	2025-11-28 11:21:14.760481	2025-11-28 11:21:14.760481
126	2	d1ae7f53-a376-47a6-abe4-a400840c0dfc	Catherine Tan	\N	\N	60128505615	\N	2025-11-28 11:21:15.696982	2025-11-28 11:21:15.696982
127	2	6beaff2c-e41d-45b2-9923-76df00b6cbd5	May Tan	\N	\N	60125599843	\N	2025-11-28 11:21:15.777844	2025-11-28 11:21:15.777844
128	2	a1671dba-73f8-4d56-b8c3-2bd7c7f45ed6	Seak Siok Hun	\N	\N	60192325623	\N	2025-11-28 11:21:17.303805	2025-11-28 11:21:17.303805
129	2	01bbdd47-521c-41b6-b99c-633462026323	Heng See Xiang	\N	\N	60127849369	\N	2025-11-28 11:21:18.396241	2025-11-28 11:21:18.396241
130	2	ee930bec-1151-4648-a380-040669e5ea9f	June Pong Chai Yen	\N	\N	60165062308	\N	2025-11-28 11:21:18.417143	2025-11-28 11:21:18.417143
131	2	a4975f33-d421-4416-ae35-6e89c4d4fd69	Pei Ling	\N	\N	60172236101	\N	2025-11-28 11:21:20.663405	2025-11-28 11:21:20.663405
132	2	d7494743-65e8-4a2d-8973-939734d8566a	Winnie Thee	\N	\N	60163608863	\N	2025-11-28 11:21:20.778969	2025-11-28 11:21:20.778969
133	2	a4ba2bb7-e7e7-40d6-9462-9fea0555ab15	Elaine Cher	\N	\N	60127721531	\N	2025-11-28 11:21:21.101306	2025-11-28 11:21:21.101306
134	2	e25d79f3-adf5-4947-bf09-ba081f535ef9	Yap Kim Choo	\N	\N	60108795686	\N	2025-11-28 11:21:21.871863	2025-11-28 11:21:21.871863
135	2	be77be28-70d4-49ef-aef5-2500f61f744e	Adam Cheng	\N	\N	60196887888	\N	2025-11-28 11:21:22.116128	2025-11-28 11:21:22.116128
136	2	6a128409-ac5c-4402-ac9f-70c8af2ec82f	Adrian Chua	\N	\N	60126742112	\N	2025-11-28 11:21:23.109861	2025-11-28 11:21:23.109861
137	2	0cad7396-b3fb-48be-8ee3-a4e1abc0a92d	Lim Jing Jie	\N	\N	60173119665	\N	2025-11-28 11:21:24.648594	2025-11-28 11:21:24.648594
138	2	2fefe496-05d4-4dd3-8e3f-27fb5cb4d466	Lee Soon Hong	\N	\N	60133770044	\N	2025-11-28 11:21:24.703892	2025-11-28 11:21:24.703892
139	2	ba4acd90-e0c9-4d3b-ba6b-7a14d04e9307	Lim Seok Ying	\N	\N	60195175961	\N	2025-11-28 11:21:24.716316	2025-11-28 11:21:24.716316
140	2	2c27cab6-c00b-4c36-a1e5-c4bc0d7d6fd4	Tey Jeat Ee	\N	\N	60122766962	\N	2025-11-28 11:21:25.256235	2025-11-28 11:21:25.256235
141	2	64d78ab6-467b-474a-a9e3-f4cfb9729ad7	Winny Chong	\N	\N	60125686863	\N	2025-11-28 11:21:25.389562	2025-11-28 11:21:25.389562
142	2	82213c1e-957d-40cd-b7bb-66cf51ad6be0	Png Hui Siang	\N	\N	60177366909	\N	2025-11-28 11:21:25.923484	2025-11-28 11:21:25.923484
143	2	47c673eb-33c9-4a73-84cd-3c7ade29262e	Violet Lee	\N	\N	60194109029	\N	2025-11-28 11:21:28.115735	2025-11-28 11:21:28.115735
144	2	456e7634-caaa-461d-953c-4b00cdb202ea	Wong Mee Kheun	\N	\N	60169966127	\N	2025-11-28 11:21:29.513182	2025-11-28 11:21:29.513182
145	2	e055cd06-39e7-43cb-b14e-f38a201aae31	Cho	\N	\N	886966111328	\N	2025-11-28 11:21:30.110124	2025-11-28 11:21:30.110124
146	2	41f50fdb-d880-4b4f-b5b6-9dac5eeb9345	Boo Xan Cian	\N	\N	601110811293	\N	2025-11-28 11:21:31.451221	2025-11-28 11:21:31.451221
147	2	c109777c-ee50-4c99-8813-1409bc4bdd95	Nuranis Alia Syafiqah Binti Shefrizal	\N	\N	601114694200	\N	2025-11-28 11:21:31.493892	2025-11-28 11:21:31.493892
148	2	016cecd1-6648-49f2-aa82-06769b84f816	Teh Siew Ngee	\N	\N	60164197616	\N	2025-11-28 11:21:31.917149	2025-11-28 11:21:31.917149
149	2	2b310e17-971c-47c1-a1da-306535631d1d	Peixin Hwam May	\N	\N	60146249883	\N	2025-11-28 11:21:32.419917	2025-11-28 11:21:32.419917
150	2	07d16c3c-3434-4ccf-a74e-e6560561d1b5	Matthias Gelber	\N	\N	60162633828	\N	2025-11-28 11:21:34.855564	2025-11-28 11:21:34.855564
151	2	062e5b9b-4340-438f-bf07-3662c54f3bc0	Liang Kim Loong	\N	\N	60124517842	\N	2025-11-28 11:21:35.015477	2025-11-28 11:21:35.015477
152	2	cbebc7d2-c92e-4a4b-986a-f107e571f7dd	Tiffany Shim	\N	\N	60198082869	\N	2025-11-28 11:21:35.228832	2025-11-28 11:21:35.228832
153	2	2b8b126e-9e04-4263-839c-ea0e214cd7da	Vayne	\N	\N	60167707388	\N	2025-11-28 11:21:35.502033	2025-11-28 11:21:35.502033
154	2	9bcba5bb-058b-4235-807c-70da1b1b6a54	David Ong	\N	\N	60104691737	\N	2025-11-28 11:21:36.35743	2025-11-28 11:21:36.35743
155	2	b35b77c5-474f-4533-b740-65f9dbc7480e	Amy Low	\N	\N	60163333929	\N	2025-11-28 11:21:37.156203	2025-11-28 11:21:37.156203
156	2	30ee1142-45b8-45b6-8ead-a8caf0b3d3f1	Jacky Tong Yee Chin	\N	\N	60175523541	\N	2025-11-28 11:21:37.586537	2025-11-28 11:21:37.586537
157	2	3d5b31b7-d0f9-45b2-a946-54ddcb8967d0	Cheah Rae Von	\N	\N	60164217210	\N	2025-11-28 11:21:37.692092	2025-11-28 11:21:37.692092
158	2	1bdc48f8-3d18-4d7b-8584-6aed8999c014	Yong Kai Yuen	\N	\N	60126782311	\N	2025-11-28 11:21:37.749147	2025-11-28 11:21:37.749147
159	2	34d12675-a752-4213-a1ec-cde79808c9d0	Joyce Ngu	\N	\N	60166729699	\N	2025-11-28 11:21:40.596984	2025-11-28 11:21:40.596984
160	2	dcab1b51-e637-4620-a5c4-e8002a93575d	Mohamad Uda Bin Taha	\N	\N	60133733396	\N	2025-11-28 11:21:40.632901	2025-11-28 11:21:40.632901
161	2	16562b7a-b525-4383-9f9b-00366ce664ff	Yens Yenkai	\N	\N	60133414343	\N	2025-11-28 11:21:42.738077	2025-11-28 11:21:42.738077
162	2	65ecf386-d580-4e5b-9231-44c1f867ffba	Tammy Wong	\N	\N	60109519431	\N	2025-11-28 11:21:43.611702	2025-11-28 11:21:43.611702
163	2	ab21ffd1-065f-4eda-9cde-ea9969c3f292	Chu Wei Jeat	\N	\N	60198891873	\N	2025-11-28 11:21:44.998253	2025-11-28 11:21:44.998253
164	2	f7630a61-01f7-494a-80e9-133a2af13dfe	Tan Xin Hui	\N	\N	60102476345	\N	2025-11-28 11:21:46.656462	2025-11-28 11:21:46.656462
165	2	75da56ac-d3f3-441a-be30-0f0e149cf5b7	Ngo Pik Huat	\N	\N	60123113699	\N	2025-11-28 11:21:46.990226	2025-11-28 11:21:46.990226
166	2	edbbf3cb-c87f-4512-bfdd-bbd1c705f182	Brenda Tay	\N	\N	60169988337	\N	2025-11-28 11:21:49.596904	2025-11-28 11:21:49.596904
167	2	6b7db292-5083-4589-88b2-53f66d6695e7	Sunny Ng Sern Wei	\N	\N	60149237686	\N	2025-11-28 11:21:50.015525	2025-11-28 11:21:50.015525
168	2	cc37ae3e-7eeb-4d59-a9b6-22951726b519	Lyvia Wong Xing Yue	\N	\N	60103159683	\N	2025-11-28 11:21:50.911654	2025-11-28 11:21:50.911654
169	2	8b5342e5-5076-4f98-ab4f-bc5732a5fbd7	Chong Mei Mei	\N	\N	60126117858	\N	2025-11-28 11:21:52.806132	2025-11-28 11:21:52.806132
170	2	7f9fa678-f792-48f7-993b-bb6a29b5a8f3	Esther Lee	\N	\N	60123642684	\N	2025-11-28 11:21:55.443849	2025-11-28 11:21:55.443849
171	2	7b24101c-5b0c-4ede-b63c-379890f3171a	Soh Shi Chee	\N	\N	60176290006	\N	2025-11-28 11:21:55.629222	2025-11-28 11:21:55.629222
172	2	c9ea62ac-e691-4d91-9b98-edb00963d19b	Karen Lee	\N	\N	60162818863	\N	2025-11-28 11:21:55.910208	2025-11-28 11:21:55.910208
173	2	5c55821e-0336-43ac-90dd-728c7da9ffe2	Lim Hui Xuan	\N	\N	60137733475	\N	2025-11-28 11:21:57.760284	2025-11-28 11:21:57.760284
174	2	cbad700f-2fd5-4127-abe5-e99c85b5d527	Tan Lay Theng	\N	\N	60176263882	\N	2025-11-28 11:21:57.838331	2025-11-28 11:21:57.838331
175	2	85a63f2a-479d-4d4c-9e71-7b9797c3d9d0	Edison Choong	\N	\N	60123653658	\N	2025-11-28 11:21:58.876798	2025-11-28 11:21:58.876798
176	2	1311d54a-555c-4d71-a789-789a6ca85aba	Chan Choon Kit	\N	\N	60197139139	\N	2025-11-28 11:22:02.186237	2025-11-28 11:22:02.186237
177	2	c63ec323-95d4-457b-a56c-ff56a9282e1d	Garie Ung	\N	\N	60193961319	\N	2025-11-28 11:22:02.841532	2025-11-28 11:22:02.841532
178	2	b313a237-8655-4f5a-864c-916ddd26101f	Frank Ong Chu Perng	\N	\N	60149677319	\N	2025-11-28 11:22:04.113178	2025-11-28 11:22:04.113178
179	2	29af9c19-0e4e-4c5a-a75e-312f59e5e037	Jerry Ngow	\N	\N	60174189368	\N	2025-11-28 11:22:05.030247	2025-11-28 11:22:05.030247
180	2	fe11db3b-3fe7-43c2-b543-0f031afe306d	Nur Ain Amiza	\N	\N	601162143844	\N	2025-11-28 11:22:05.085533	2025-11-28 11:22:05.085533
181	2	3b33a30f-c641-4148-af6f-708330f7a051	You Hui Hui	\N	\N	60166856888	\N	2025-11-28 11:22:05.453401	2025-11-28 11:22:05.453401
182	2	9bcc06fd-cc32-4f28-91d2-1aa8a4f1c6ff	Susan Lim	\N	\N	60165853212	\N	2025-11-28 11:22:05.55591	2025-11-28 11:22:05.55591
183	2	d14c6963-cb56-4819-80ba-e2bddb82cc31	Loh Chui Theng	\N	\N	60172530521	\N	2025-11-28 11:22:07.038723	2025-11-28 11:22:07.038723
184	2	932b9abf-d473-4365-8aba-34df435c143d	Tay Lee Gain	\N	\N	60162008200	\N	2025-11-28 11:22:08.245041	2025-11-28 11:22:08.245041
185	2	61e0438c-b715-471c-8fa3-d162d7a1fd2b	Ng Lei Kuan	\N	\N	60122141383	\N	2025-11-28 11:22:09.969961	2025-11-28 11:22:09.969961
186	2	d399615d-4d76-46a4-878c-ad08eda1ac09	Ong Shy Piau	\N	\N	60196621213	\N	2025-11-28 11:22:13.281645	2025-11-28 11:22:13.281645
187	2	efb3c4dc-41f3-4364-884a-ed1e2494c3c9	Lau Sook Hui	\N	\N	60187784487	\N	2025-11-28 11:22:14.572204	2025-11-28 11:22:14.572204
188	2	f3d8661d-cf77-452b-bd52-503a36e0b911	Thong Hao Lun	\N	\N	601131942042	\N	2025-11-28 11:22:15.073595	2025-11-28 11:22:15.073595
189	2	2b0ff022-7158-4168-888a-9374f9d250bd	Fong Kah Khee	\N	\N	60194726657	\N	2025-11-28 11:22:15.668531	2025-11-28 11:22:15.668531
190	2	b7690d3e-70a0-43e1-b57f-492bbcd2a7c2	Tan Shy Sieng	\N	\N	60125113212	\N	2025-11-28 11:22:16.882054	2025-11-28 11:22:16.882054
191	2	299d0832-cca1-41fb-8eb2-085bba869a6b	Soh Ching Ping	\N	\N	60129696826	\N	2025-11-28 11:22:17.327052	2025-11-28 11:22:17.327052
192	2	4c0f2b96-74d6-4ddf-8bb9-ce774dd9f450	Alan Yow	\N	\N	60193347015	\N	2025-11-28 11:22:22.198233	2025-11-28 11:22:22.198233
193	2	a71a07e6-df8a-48b4-a2a1-0d2ae6385f40	Ngleeze	\N	\N	601156602228	\N	2025-11-28 11:22:22.60833	2025-11-28 11:22:22.60833
194	2	4de33758-7fd2-47df-9dc0-678c8ec657d7	Teow Wai Fatt	\N	\N	60164228516	\N	2025-11-28 11:22:30.402119	2025-11-28 11:22:30.402119
195	2	481c5cdf-7ab8-45c9-8559-1aa1d63622e1	Jeremy Chua	\N	\N	60127292020	\N	2025-11-28 11:22:31.556815	2025-11-28 11:22:31.556815
196	2	13d239a1-1e98-419e-9a17-4372b787d694	Christopher Chia	\N	\N	60127988238	\N	2025-11-28 11:22:32.476062	2025-11-28 11:22:32.476062
197	2	5e4363ae-c1d1-44b2-b55c-8b6b3c3ee1b4	Samuel Ng	\N	\N	60129450555	\N	2025-11-28 11:22:33.93586	2025-11-28 11:22:33.93586
198	2	16bd5817-0114-44d0-a826-174178e81081	Liu Rq	\N	\N	60123886353	\N	2025-11-28 11:22:33.944227	2025-11-28 11:22:33.944227
199	2	b9e30896-5969-43b7-b06f-286bf2fe99aa	Lee Keing Yong	\N	\N	60163298939	\N	2025-11-28 11:22:39.686995	2025-11-28 11:22:39.686995
200	2	c55f5be0-a6af-4dae-8a0b-d3b6c255e86e	Loke Pui San	\N	\N	601110685157	\N	2025-11-28 11:22:40.716238	2025-11-28 11:22:40.716238
201	2	e1bfc171-6437-4689-bff1-93fc4b97ff01	Lim Khan Ni	\N	\N	60162800253	\N	2025-11-28 11:22:42.625546	2025-11-28 11:22:42.625546
202	2	55e860d1-41e7-4360-b3b7-7577b92259fd	Lau Aun Kee	\N	\N	60174137661	\N	2025-11-28 11:22:42.776223	2025-11-28 11:22:42.776223
203	2	f9a7a063-f759-4b5f-a37d-9775bdcdeeaa	Max Lee	\N	\N	60123141954	\N	2025-11-28 11:22:44.030916	2025-11-28 11:22:44.030916
204	2	fe5dcd15-c580-431c-9d1c-e31ad2a631db	So Zhi Hui	\N	\N	60129887985	\N	2025-11-28 11:22:46.20009	2025-11-28 11:22:46.20009
205	2	de249064-3d6c-4619-b998-db2c6eb313bd	Eric Leong Khar Hing	\N	\N	601156580556	\N	2025-11-28 11:22:46.713916	2025-11-28 11:22:46.713916
206	2	4e5c7314-2528-48fa-90b4-87ad55a6183a	Guan Tian Lai	\N	\N	60126783565	\N	2025-11-28 11:22:46.772164	2025-11-28 11:22:46.772164
207	2	1b121c52-10bf-4bc3-8fb2-25c5575b8320	Chong Yeong Kon	\N	\N	60173333885	\N	2025-11-28 11:22:47.476443	2025-11-28 11:22:47.476443
208	2	f486d844-aa04-48d9-8c3c-bde1263dae60	Veman Koh Wai Seng	\N	\N	60163239899	\N	2025-11-28 11:22:50.209967	2025-11-28 11:22:50.209967
209	2	a3fa4ee0-7b31-41dd-a297-febafd291f0a	Alex Li	\N	\N	60178578948	\N	2025-11-28 11:22:55.183797	2025-11-28 11:22:55.183797
210	2	e698576e-b06e-4d3b-9256-8e5980689da1	Hoh Hui Wen	\N	\N	60162366138	\N	2025-11-28 11:22:55.268988	2025-11-28 11:22:55.268988
211	2	344ece8c-3577-4fd1-ab5f-d3d6e557626f	Law Boon Leng	\N	\N	60172223012	\N	2025-11-28 11:22:56.353577	2025-11-28 11:22:56.353577
212	2	56f9dc61-e336-4db3-81a5-578bdfe34cca	Teh Jin Yuan	\N	\N	60166206520	\N	2025-11-28 11:22:57.378038	2025-11-28 11:22:57.378038
213	2	e5b25998-9861-4fea-ba82-567286c673af	Choong Lee Sy	\N	\N	60126201380	\N	2025-11-28 11:22:58.890934	2025-11-28 11:22:58.890934
214	2	f949ad7a-125a-4b20-bcab-9494f0e51b6a	Niq Chong	\N	\N	60163933994	\N	2025-11-28 11:23:01.029175	2025-11-28 11:23:01.029175
215	2	910feddb-51e2-44b8-910d-74791c091653	Ally Chai	\N	\N	60179111496	\N	2025-11-28 11:23:01.406956	2025-11-28 11:23:01.406956
216	2	7a4feaee-877c-4a94-a904-3299dd822ec9	Ong Sze Miq	\N	\N	60169936597	\N	2025-11-28 11:23:03.058109	2025-11-28 11:23:03.058109
217	2	cc4689f8-0a4d-45c9-b3d8-123c7602c368	Lee Jia Hong	\N	\N	60126838628	\N	2025-11-28 11:23:04.896015	2025-11-28 11:23:04.896015
218	2	064f69d8-6efa-4958-b3ab-d3c347f86698	Ng Choon Chin	\N	\N	60166301196	\N	2025-11-28 11:23:07.10376	2025-11-28 11:23:07.10376
219	2	a3d0f4b2-a773-4631-ab94-1b24454a785d	Tan Xinyi	\N	\N	60176814527	\N	2025-11-28 11:23:07.370914	2025-11-28 11:23:07.370914
220	2	46ab4b5d-f048-4f80-b26f-3ccdc81c2689	Kong Sou Keet	\N	\N	60125276771	\N	2025-11-28 11:23:07.693504	2025-11-28 11:23:07.693504
221	2	bd644328-c5d0-4e25-a770-d498fb2e3059	Dato Seri Dr. Raymond Liew	\N	\N	60123821768	\N	2025-11-28 11:23:08.359281	2025-11-28 11:23:08.359281
222	2	a1b1bf36-47cd-4458-a125-f71c18b6989e	Jessie Lee Chin Wen	\N	\N	60123923770	\N	2025-11-28 11:23:08.63946	2025-11-28 11:23:08.63946
223	2	ad7211bc-1ed3-4e70-b580-00c208966b75	Lee Chee Wen	\N	\N	60164147931	\N	2025-11-28 11:23:08.719928	2025-11-28 11:23:08.719928
224	2	a679be22-cabb-4213-a4ce-057040fa2ef0	Chong Fang Hon	\N	\N	60176307157	\N	2025-11-28 11:23:08.79415	2025-11-28 11:23:08.79415
225	2	efa3775a-60de-4ead-aebb-e98565045f9b	Helen Tan	\N	\N	60167331302	\N	2025-11-28 11:23:08.832481	2025-11-28 11:23:08.832481
226	2	a730e575-0b8f-4e98-bf84-36861b737919	Chong Meng Keong	\N	\N	60143016864	\N	2025-11-28 11:23:09.305199	2025-11-28 11:23:09.305199
227	2	6c33ebb9-cc80-49bf-bb81-87a82906f72d	Ng Chiew Sien	\N	\N	60123983102	\N	2025-11-28 11:23:11.801306	2025-11-28 11:23:11.801306
228	2	a2112a4d-0f45-4580-80fc-14fa6f9348fa	Looi Lei Chuen	\N	\N	60175622134	\N	2025-11-28 11:23:14.839629	2025-11-28 11:23:14.839629
229	2	a92d67cf-5648-4cdb-88b5-34b31f8c3044	Eaden Chow	\N	\N	60165196540	\N	2025-11-28 11:23:15.996118	2025-11-28 11:23:15.996118
230	2	cd838bfb-1e41-4632-803c-789818243937	Low Yun Ia	\N	\N	60139672685	\N	2025-11-28 11:23:24.507512	2025-11-28 11:23:24.507512
231	2	5e25516f-a833-43aa-baaa-d46510f982bd	Yew Wen Swen	\N	\N	60123392134	\N	2025-11-28 11:23:25.386442	2025-11-28 11:23:25.386442
232	2	fd827292-7eb5-40cf-b8b9-f6e6787bcacc	Shelly Kam	\N	\N	60177040383	\N	2025-11-28 11:23:26.245523	2025-11-28 11:23:26.245523
233	2	430b4796-e4ba-4ae6-9264-c060420d58c3	Wong Yu Xuan	\N	\N	60137417728	\N	2025-11-28 11:23:26.565613	2025-11-28 11:23:26.565613
234	2	507118ea-0b44-4cf8-8509-ed706b18bf28	Ken Tan	\N	\N	601126311283	\N	2025-11-28 11:23:26.720216	2025-11-28 11:23:26.720216
235	2	20f01d7d-750a-4188-802d-b8c91edbc0f2	Yew Hao Sheng	\N	\N	60125672134	\N	2025-11-28 11:23:27.663914	2025-11-28 11:23:27.663914
236	2	4e02560a-0158-4cb6-a752-870ad0c9215e	Foong Sok Kee	\N	\N	60165061608	\N	2025-11-28 11:23:28.161433	2025-11-28 11:23:28.161433
237	2	e4419f55-990f-4029-b40e-210155c5eb1f	Lim Guat Peng	\N	\N	60122119897	\N	2025-11-28 11:23:30.427755	2025-11-28 11:23:30.427755
238	2	8315009f-cf48-4ed1-8d7e-9343035dd0d2	Phoon Weng Kit	\N	\N	60124602677	\N	2025-11-28 11:23:30.557286	2025-11-28 11:23:30.557286
239	2	6d0c7079-a842-43ab-9f72-18a00ade747f	Jay Chow	\N	\N	60122738225	\N	2025-11-28 11:23:33.631049	2025-11-28 11:23:33.631049
240	2	0725b066-cee4-4bcd-9117-d393bb24a9c6	Lim Lee Yen	\N	\N	60193277953	\N	2025-11-28 11:23:39.606267	2025-11-28 11:23:39.606267
241	2	979fdeb1-fb31-44d4-bc34-bb89c6c90d5b	Lim Tong Seng	\N	\N	60127046428	\N	2025-11-28 11:23:46.096818	2025-11-28 11:23:46.096818
242	2	a101eab0-4cad-432c-b4fb-352f057f7a4c	Kelvin Foong	\N	\N	60125692188	\N	2025-11-28 11:23:48.692175	2025-11-28 11:23:48.692175
243	2	c1329a23-02de-425f-8f56-7dff75662304	Lee Kai Teng	\N	\N	60109359434	\N	2025-11-28 11:23:49.051983	2025-11-28 11:23:49.051983
244	2	14bf6d25-bc7e-4842-a45c-d2e0b88d4382	Poon Fong Mun	\N	\N	60166661690	\N	2025-11-28 11:23:49.860418	2025-11-28 11:23:49.860418
245	2	3b25bc81-9c40-45d0-827e-d474cb2d167c	Carmen Lau Man Yan	\N	\N	60189478088	\N	2025-11-28 11:23:50.419253	2025-11-28 11:23:50.419253
246	2	c60cc3f6-00a1-4468-a291-fa841e8f8f30	Yap Kah Fung	\N	\N	601127609026	\N	2025-11-28 11:23:50.740806	2025-11-28 11:23:50.740806
247	2	e7bc3c80-ee69-4626-a83b-411530683574	Faihan Ghani	\N	\N	60193141395	\N	2025-11-28 11:23:50.941262	2025-11-28 11:23:50.941262
248	2	01085b27-5a1e-4ad2-9256-176abe0920e8	Pang Yoon Chu	\N	\N	60167786902	\N	2025-11-28 11:23:51.18172	2025-11-28 11:23:51.18172
249	2	22e60fbb-3511-4e8a-bcef-ff752ce28971	Ipk College	\N	\N	60124300455	\N	2025-11-28 11:23:51.252272	2025-11-28 11:23:51.252272
250	2	4556f914-c247-43de-b55d-7220548ad643	Rachel Hsu Xin	\N	\N	60129233183	\N	2025-11-28 11:23:56.188653	2025-11-28 11:23:56.188653
251	2	aa10e682-d528-46bb-a932-12cb80934e3c	Loh Jia Hao	\N	\N	60176610678	\N	2025-11-28 11:24:12.015373	2025-11-28 11:24:12.015373
252	2	59a9955c-1bff-4281-bdd9-107c68f9962a	Tan Lay Peng	\N	\N	60123351228	\N	2025-11-28 11:24:15.074642	2025-11-28 11:24:15.074642
253	2	7dd19bd6-4aa7-434a-a684-31a2050fd504	Lam Song Ann	\N	\N	601127287768	\N	2025-11-28 11:24:15.870908	2025-11-28 11:24:15.870908
254	2	52b1c1a4-d467-492c-9118-5c3d60cf615c	Lim Bee Teng	\N	\N	60169296078	\N	2025-11-28 11:24:16.116163	2025-11-28 11:24:16.116163
255	2	cc6b9405-40dc-4b86-b320-4d0004987950	Pua Siong Foo	\N	\N	60122383764	\N	2025-11-28 11:24:16.330589	2025-11-28 11:24:16.330589
256	2	7e877ab2-dc14-46f3-9e04-c57be562876a	Ng Fong Mei	\N	\N	60123138522	\N	2025-11-28 11:24:16.774969	2025-11-28 11:24:16.774969
257	2	7ae8f410-86aa-4ed5-9d3c-22de827d94ae	Yeow Kim Kiat	\N	\N	60192359771	\N	2025-11-28 11:24:18.586516	2025-11-28 11:24:18.586516
258	2	75c204ae-5251-41c1-9e4a-4b363221e5de	Wow Khai Fong	\N	\N	60127523119	\N	2025-11-28 11:24:24.335317	2025-11-28 11:24:24.335317
259	2	b8e21de3-f1cc-487e-98c4-0ece28aec174	Max Lee	\N	\N	601162868287	\N	2025-11-28 11:24:30.681508	2025-11-28 11:24:30.681508
260	2	0b64781e-572e-4801-b5c2-a27d20bd28d0	Au Yong Joon Yow	\N	\N	601116388132	\N	2025-11-28 11:24:45.563453	2025-11-28 11:24:45.563453
261	2	a5ccfe6a-7537-426a-bd45-1c857bb26547	Chea Bik Yin	\N	\N	60176010199	\N	2025-11-28 11:24:47.262565	2025-11-28 11:24:47.262565
262	2	6741832f-b05f-4abb-ab22-b6898f210852	Stella Chu Vui Yen	\N	\N	60168839782	\N	2025-11-28 11:24:47.391077	2025-11-28 11:24:47.391077
263	2	c86cc120-5b85-42f6-8fb5-76db01b0774b	Wing Foo Yuen	\N	\N	60143328814	\N	2025-11-28 11:24:48.477321	2025-11-28 11:24:48.477321
264	2	f642ecac-e3dd-4008-9367-b414a815659c	Low Yoke Yin	\N	\N	601120666743	\N	2025-11-28 11:24:50.408659	2025-11-28 11:24:50.408659
265	2	59e25ce3-c862-43e4-9a9b-ddfc94b9eb61	Lee Peck Hoon	\N	\N	60123178339	\N	2025-11-28 11:24:57.184096	2025-11-28 11:24:57.184096
266	2	3b0ff214-1650-4ac8-a594-e07f2aa216a7	Amy Yong	\N	\N	60183933988	\N	2025-11-28 11:24:58.325819	2025-11-28 11:24:58.325819
267	2	e7b3d751-b707-469b-99d6-609d5fd7ff33	Robert Choy Chik Hai	\N	\N	60123293988	\N	2025-11-28 11:25:06.302996	2025-11-28 11:25:06.302996
268	2	fb30383d-ce50-4c55-96b3-3632e362ddab	Hoe Mey Key	\N	\N	60102320959	\N	2025-11-28 11:25:14.961498	2025-11-28 11:25:14.961498
269	2	2094853e-6eb2-45e2-b4e7-83543054eeba	Sin Zong Yi	\N	\N	60184089799	\N	2025-11-28 11:25:17.947977	2025-11-28 11:25:17.947977
270	2	891353d5-f667-4d3d-8558-04141ddc2def	Pua Wooi Chin	\N	\N	60165943876	\N	2025-11-28 11:25:28.990927	2025-11-28 11:25:28.990927
271	2	dd2583f5-ca08-4d48-93a4-9b9d470b4643	Meiling	\N	\N	60122333278	\N	2025-11-28 11:25:33.289554	2025-11-28 11:25:33.289554
272	2	cecfb16b-1c80-4856-9ee6-0382f2e95bfe	Clodi	\N	\N	60163323956	\N	2025-11-28 11:25:38.095831	2025-11-28 11:25:38.095831
273	2	ac4bdc0a-bcc9-482d-b36d-94d1f8307d90	Chan Soek Kean	\N	\N	60126924077	\N	2025-11-28 11:25:55.480052	2025-11-28 11:25:55.480052
274	2	4c8842f2-b7c8-4709-933d-8f24d0afa228	Shirley Yap	\N	\N	60163055291	\N	2025-11-28 11:26:05.256234	2025-11-28 11:26:05.256234
275	2	4ea4cb90-00d2-44a5-ae13-75af80bb33e9	Bay Joo Kuen	\N	\N	60124485838	\N	2025-11-28 11:26:18.034679	2025-11-28 11:26:18.034679
276	2	fc547cfd-d29f-4203-84e7-dfeab3813a98	Kam Nguk Siang	\N	\N	60192727929	\N	2025-11-28 11:26:22.461247	2025-11-28 11:26:22.461247
277	2	eac3d079-2aad-4c4a-bb22-33ef8a4b59de	Foong Mei Kei	\N	\N	60126697688	\N	2025-11-28 11:26:25.512861	2025-11-28 11:26:25.512861
278	2	9bf3153b-f36c-4b3e-a64b-40538a7b43bd	Wuu Kok Wai	\N	\N	60173801663	\N	2025-11-28 11:26:28.783273	2025-11-28 11:26:28.783273
279	2	480da33c-506e-4926-ac54-375196e76c24	Lee Pei Yen	\N	\N	60123066060	\N	2025-11-28 11:26:45.085501	2025-11-28 11:26:45.085501
280	2	97c23620-69e4-4284-9fc3-f9f3ea0e5f2f	Adam	\N	\N	639504426833	\N	2025-11-28 11:27:04.37276	2025-11-28 11:27:04.37276
281	2	e7cfbf5e-b902-439c-a228-ab2b8d37ee4f	Lee Pei Yen	\N	\N	60127126642	\N	2025-11-28 11:27:52.14202	2025-11-28 11:27:52.14202
282	2	584e9043-3da9-4705-8406-09516908db8d	Chuah Phoi Shan	\N	\N	60102601735	\N	2025-11-28 11:28:07.823763	2025-11-28 11:28:07.823763
283	2	b6d931d4-cba0-4ea9-b394-26faf5a494d6	Janet Loh	\N	\N	60167350570	\N	2025-11-28 11:28:17.533163	2025-11-28 11:28:17.533163
284	2	c6b710c9-5861-4f0b-8b4c-c67d454031b3	Chai Man Jing	\N	\N	60179111496	\N	2025-11-28 11:28:19.510729	2025-11-28 11:28:19.510729
285	2	e2477d67-09b1-42f9-bab0-acce6e1495e0	Kyle Soo Kok Leong	\N	\N	60164910049	\N	2025-11-28 11:29:39.660123	2025-11-28 11:29:39.660123
286	2	67aec412-47e1-4d2e-9a38-5dc78c8b3f11	Alice	\N	\N	60189785901	\N	2025-11-28 11:30:03.438095	2025-11-28 11:30:03.438095
287	2	08cf8b81-9fd1-4554-bef3-92429430293d	Peter Yu	\N	\N	601157288278	\N	2025-11-28 11:32:01.430648	2025-11-28 11:32:01.430648
288	2	1baa3e2b-041d-47ad-9d32-b3f66b3679a7	Hoo San San	\N	\N	601163696491	\N	2025-11-28 11:32:18.210482	2025-11-28 11:32:18.210482
289	2	52e5e1de-a57c-41e3-b95e-0999197ee13f	Visky Foong Mei Teng	\N	\N	60125588077	\N	2025-11-28 11:32:21.498058	2025-11-28 11:32:21.498058
290	2	685cada1-3faf-43b5-ae55-1e03d3f910df	Jerald Ang	\N	\N	601121112821	\N	2025-11-28 11:34:15.743477	2025-11-28 11:34:15.743477
291	2	ba19f4de-52d9-4951-a570-f38c63e99599	Wun Jun Ming	\N	\N	60166783591	\N	2025-11-28 11:44:49.921454	2025-11-28 11:44:49.921454
292	2	693fc723-8866-425b-9f09-907035188bf1	Law Ting Ting	\N	\N	60196484103	\N	2025-11-28 11:45:43.056523	2025-11-28 11:45:43.056523
293	2	4e2ab498-8ec6-4b6b-8e0b-cdc7b7968f34	Wan Yi Yean	\N	\N	60129810429	\N	2025-11-28 11:47:14.634618	2025-11-28 11:47:14.634618
294	2	f77a3032-f992-4db4-8f18-20d7e3da27bf	Kelvin Hew	\N	\N	60102202036	\N	2025-11-28 11:47:19.896597	2025-11-28 11:47:19.896597
295	2	97876a50-d00b-411a-b383-f9efff1c443e	Roy Lim	\N	\N	60173063364	\N	2025-11-28 11:47:28.533042	2025-11-28 11:47:28.533042
296	2	62b053a2-6577-49f2-923c-9db408860567	Teh Ting Ling	\N	\N	60133414303	\N	2025-11-28 11:48:13.567242	2025-11-28 11:48:13.567242
297	2	67c2a0be-a967-4635-8de4-2c240b7d2c76	Sim Char Meng	\N	\N	60143204031	\N	2025-11-28 11:55:23.360238	2025-11-28 11:55:23.360238
298	2	475154f2-3604-4ee8-bae5-1a2780434c2f	Liana Ng Chai Lian	\N	\N	60122106368	\N	2025-11-28 11:58:24.596978	2025-11-28 11:58:24.596978
299	2	884b2d12-18bb-4381-9393-faa665fb150d	Tan Lee Ting	\N	\N	60176678608	\N	2025-11-28 11:58:36.761613	2025-11-28 11:58:36.761613
300	2	62b399cd-c9be-4030-ad78-18042a4b5858	Lim Huang Zhe	\N	\N	60173989980	\N	2025-11-28 11:59:17.695567	2025-11-28 11:59:17.695567
301	2	deb84c98-3893-485f-9f9f-d7fe8e93629e	Terry Swee	\N	\N	601165318685	\N	2025-11-28 12:01:38.902882	2025-11-28 12:01:38.902882
302	2	bc171221-0cad-432a-999e-2bb88e39ed07	Gilbert	\N	\N	60178931471	\N	2025-11-28 12:01:51.489023	2025-11-28 12:01:51.489023
303	2	c0f3e24c-41ff-4a43-8a95-e3334071bbeb	Alec Ooi Boon Hao	\N	\N	60164730777	\N	2025-11-28 12:01:55.256199	2025-11-28 12:01:55.256199
304	2	eeca6434-a4e1-40ba-bf06-1d2dfe7a4c88	Cindy Yeoh Gim Suan	\N	\N	60122001303	\N	2025-11-28 12:02:00.540763	2025-11-28 12:02:00.540763
305	2	f8617651-cee8-4cf7-b167-e673d192bc5d	Lee Qing Feng	\N	\N	60122179112	\N	2025-11-28 12:02:02.326991	2025-11-28 12:02:02.326991
306	2	b13e65de-9183-4aa3-a86a-7298edeac383	Chu Voon Sing	\N	\N	60109336235	\N	2025-11-28 12:02:02.510595	2025-11-28 12:02:02.510595
307	2	62e76245-3b4a-4d27-bcbb-12bcaf3878bf	Ryan Tan	\N	\N	60162759626	\N	2025-11-28 12:02:02.853794	2025-11-28 12:02:02.853794
308	2	d2263b38-9d92-43fa-afa3-f4d9b1ffbb5b	Kelvin Cheong Kok Weng	\N	\N	60122982007	\N	2025-11-28 12:02:04.046242	2025-11-28 12:02:04.046242
309	2	df5bd9d9-868e-46e3-98a2-68bd95e2b6a3	Jonathan Joseph Benedict	\N	\N	60109446019	\N	2025-11-28 12:02:04.72758	2025-11-28 12:02:04.72758
310	2	cfe56031-fbdc-4b2b-ae1e-146bbee6f5cf	Tk Tye Kok Loong	\N	\N	60162834363	\N	2025-11-28 12:02:08.188037	2025-11-28 12:02:08.188037
311	2	1fc18581-8a02-4daf-96bc-0ecfecc44b7c	Lexus Leong	\N	\N	60143901491	\N	2025-11-28 12:02:09.818826	2025-11-28 12:02:09.818826
312	2	0cdfefb8-7088-4ace-afbd-bd4b6f2a1459	Patrick Chiam	\N	\N	60168328116	\N	2025-11-28 12:02:10.057452	2025-11-28 12:02:10.057452
313	2	ca624713-ba25-48ef-848b-96ede5c3bf39	Lim Chin Hou	\N	\N	601131238852	\N	2025-11-28 12:02:11.540204	2025-11-28 12:02:11.540204
314	2	bcc5aff4-0670-4bda-8a64-8b5aeb3fd81e	Lim E Ming	\N	\N	60166682628	\N	2025-11-28 12:02:14.397251	2025-11-28 12:02:14.397251
315	2	6cf43d0b-cc22-45db-8e67-47498ced85d9	Rainb Lim Chee Yao	\N	\N	60125237616	\N	2025-11-28 12:02:16.373722	2025-11-28 12:02:16.373722
316	2	786443f7-d718-4a38-8e7f-56b85cd38e9c	Wong Hsi Nyee	\N	\N	60163112479	\N	2025-11-28 12:02:18.444426	2025-11-28 12:02:18.444426
317	2	7ee2199e-b39c-4c30-8962-657e4d3ea3eb	Chia Yang Yie	\N	\N	60146115317	\N	2025-11-28 12:02:22.351089	2025-11-28 12:02:22.351089
318	2	66e4c9b3-7529-46fb-a20d-69b65e343d1a	Alson Lim Ching Wah	\N	\N	60195903191	\N	2025-11-28 12:02:23.979989	2025-11-28 12:02:23.979989
319	2	6ef379da-8949-4e85-acd0-8eaba3541ea7	Yong Ton Lee	\N	\N	60122356099	\N	2025-11-28 12:02:25.255517	2025-11-28 12:02:25.255517
320	2	8fcba81f-9103-4d76-b04a-dd46d8a92214	Sky Wong	\N	\N	60129316699	\N	2025-11-28 12:02:26.846451	2025-11-28 12:02:26.846451
321	2	6b04c7e4-5bfb-4470-b805-0a748aaeddfc	Adrian Lim	\N	\N	60103401534	\N	2025-11-28 12:02:26.923452	2025-11-28 12:02:26.923452
322	2	72be70e0-143a-44a5-b339-e13e3c898462	Sze Kok Hoong	\N	\N	60193981186	\N	2025-11-28 12:02:27.904641	2025-11-28 12:02:27.904641
323	2	7da07f32-18ab-4ff9-b7c9-ea6bc3c506b9	William Wong	\N	\N	60124898658	\N	2025-11-28 12:02:28.852454	2025-11-28 12:02:28.852454
324	2	0546bef9-8d79-4d68-9257-78addde86b2e	Dato Jennifer Ong	\N	\N	60123968478	\N	2025-11-28 12:02:36.022673	2025-11-28 12:02:36.022673
325	2	2f6a4e44-cf16-4576-9955-ab87abfa5c85	Muhammad Khalis Bin Noor Hisham	\N	\N	60172359155	\N	2025-11-28 12:02:40.11738	2025-11-28 12:02:40.11738
326	2	ca5835e0-db68-4127-be5f-e7ff4c42ebc8	Leonard Yap	\N	\N	60126959832	\N	2025-11-28 12:02:40.167708	2025-11-28 12:02:40.167708
327	2	5e007bf1-5518-406c-a69f-02a7d6bc6ca4	Melvin Tay Hai Chuang	\N	\N	60126060746	\N	2025-11-28 12:02:40.963692	2025-11-28 12:02:40.963692
328	2	a28b394f-b734-46b9-8e42-bb7791e50475	Lee Beng Teik	\N	\N	60165926109	\N	2025-11-28 12:02:41.031613	2025-11-28 12:02:41.031613
329	2	59372b78-2043-402c-979f-5ef6f322ff84	Sofia Leong Abdullah	\N	\N	60196222691	\N	2025-11-28 12:02:41.571847	2025-11-28 12:02:41.571847
330	2	056d9856-706f-4dd4-b2f4-84a91da3f391	Jocelyn Leong	\N	\N	601152855555	\N	2025-11-28 12:02:42.012896	2025-11-28 12:02:42.012896
331	2	e1171ffc-50e8-49f2-ad49-303417f58637	Celeste Lim	\N	\N	60106018222	\N	2025-11-28 12:02:45.834626	2025-11-28 12:02:45.834626
332	2	a3f69e69-514e-4c2d-bc1f-bbccbf10fe8d	Poon Jing Xiong	\N	\N	60122120215	\N	2025-11-28 12:02:51.47343	2025-11-28 12:02:51.47343
333	2	732991f8-e7d8-4a52-8e11-3f3dfceb1b77	Teena Chang	\N	\N	60129212872	\N	2025-11-28 12:02:56.85399	2025-11-28 12:02:56.85399
334	2	44bf0fff-fe66-4642-9087-9ee275ab1d62	Teoh Xing Ying	\N	\N	601113018631	\N	2025-11-28 12:02:57.485241	2025-11-28 12:02:57.485241
335	2	a93ddc2f-fa83-4c0b-bf7e-ac7ccace78ee	Eric Chaow	\N	\N	60173376608	\N	2025-11-28 12:03:02.418776	2025-11-28 12:03:02.418776
336	2	3da4547c-fa30-43f9-83a5-30aeb816a37c	Chia Wendy	\N	\N	60125185035	\N	2025-11-28 12:03:09.197879	2025-11-28 12:03:09.197879
337	2	f36ae10b-32ac-4e9a-b6c3-6663ccead8f1	Yong Siow Chie	\N	\N	60163276319	\N	2025-11-28 12:03:12.251163	2025-11-28 12:03:12.251163
338	2	ec002ade-61bb-421c-895c-faaca88141c9	Muhammad Khalif Bin Noor Hisham	\N	\N	601127676313	\N	2025-11-28 12:03:28.514484	2025-11-28 12:03:28.514484
339	2	ed27af76-1ac0-4084-af6e-ce20056e923f	Kelvin Chong	\N	\N	60173500512	\N	2025-11-28 12:03:35.064814	2025-11-28 12:03:35.064814
340	2	72d09937-88cf-45d4-b400-840d08dab9a2	Eric Chaow	\N	\N	60173376608	\N	2025-11-28 12:03:45.162336	2025-11-28 12:03:45.162336
341	2	5375fafd-9975-40b7-b54b-6866cdf192fc	Wong Kai Ying	\N	\N	60196818988	\N	2025-11-28 12:03:49.967038	2025-11-28 12:03:49.967038
342	2	50dc4046-73c4-4810-acb2-6e54504bdab3	Yap Chun Wai (gary)	\N	\N	60163636686	\N	2025-11-28 12:03:50.038127	2025-11-28 12:03:50.038127
343	2	4c3c4710-3ced-435c-b5f9-9cc2564f4315	Steve Manpal Singh	\N	\N	60123362268	\N	2025-11-28 12:03:57.661638	2025-11-28 12:03:57.661638
344	2	159fee43-ac11-416e-ae1e-1511994c18ef	Tong Kim Hong	\N	\N	60127990956	\N	2025-11-28 12:04:01.420493	2025-11-28 12:04:01.420493
345	2	bf7ed87b-dba4-49a6-a2eb-21e8df1ade59	Lakshmi Sam	\N	\N	60166505429	\N	2025-11-28 12:04:10.353717	2025-11-28 12:04:10.353717
346	2	95348bc7-963a-42df-94cd-4fb94193ca39	Ee Lai Chin	\N	\N	60122769377	\N	2025-11-28 12:04:17.553234	2025-11-28 12:04:17.553234
347	2	707ba0b4-745d-4a1d-96bc-5732cc1af82e	Khairin Afina Noor Hisham	\N	\N	60172262919	\N	2025-11-28 12:04:44.489414	2025-11-28 12:04:44.489414
348	2	49e7658c-b868-40df-8682-348b5f33d285	Jeff Ng	\N	\N	60129074060	\N	2025-11-28 12:04:50.434187	2025-11-28 12:04:50.434187
349	2	ac8b444f-ddc5-489e-9832-40d7e9d5ec0e	Dennis Ting Sze Yang	\N	\N	60126013689	\N	2025-11-28 12:04:51.035365	2025-11-28 12:04:51.035365
350	2	80ee31d2-8226-4171-80e9-5d5afe376ca4	Stephanie Yong En Hua	\N	\N	60137784954	\N	2025-11-28 12:05:42.646449	2025-11-28 12:05:42.646449
351	2	baa76ddf-26f7-41c4-958f-83fbbbc723f1	Johnny Lim Yuen Jiang	\N	\N	60102713763	\N	2025-11-28 12:06:40.138665	2025-11-28 12:06:40.138665
352	2	3573b455-2e7f-46c9-96eb-fb69143e4897	Puan Sri Nik Suwaida Bt Nik Mohd Mohyideen	\N	\N	60129050385	\N	2025-11-28 12:07:25.161895	2025-11-28 12:07:25.161895
353	2	e7914080-73a8-47e4-accb-68e81ec98096	Soo Soon Kid	\N	\N	60178785337	\N	2025-11-28 12:11:58.131978	2025-11-28 12:11:58.131978
354	2	8d82d832-0d58-4193-a870-4a4e377b9b5b	Louis Yeoh	\N	\N	60125265839	\N	2025-11-28 12:14:33.673801	2025-11-28 12:14:33.673801
355	2	a53cbb8e-5190-415c-a0bd-28b3b1389baa	Chloe Chan	\N	\N	60193227886	\N	2025-11-28 12:15:25.225262	2025-11-28 12:15:25.225262
356	2	b98d64c6-9b0c-4873-9ed3-ce15c15a8d4b	Muhammad Khair Bin Noor Hisham	\N	\N	60192535681	\N	2025-11-28 12:16:38.155286	2025-11-28 12:16:38.155286
357	2	510c71f8-4f1c-4f3f-9c74-740f81e80c39	Tan Huei Ping	\N	\N	60177838780	\N	2025-11-28 12:25:02.456984	2025-11-28 12:25:02.456984
358	2	7911f55d-a0bb-4fc7-8ed7-c17a0fe48d86	Tan Kai Li	\N	\N	60178706333	\N	2025-11-28 12:35:23.552727	2025-11-28 12:35:23.552727
359	2	85de8c61-9030-4283-b07d-5e137dc66ece	See Meow Teng	\N	\N	60122240448	\N	2025-11-28 12:38:53.311549	2025-11-28 12:38:53.311549
360	2	8acca054-2b7c-4aeb-9c58-6be7d2281f72	Eddie Ho	\N	\N	60163333929	\N	2025-11-28 12:41:30.475663	2025-11-28 12:41:30.475663
361	2	a227aa6e-182b-4947-810a-345344176a6e	Janet	\N	\N	60122050911	\N	2025-11-28 12:51:28.930308	2025-11-28 12:51:28.930308
362	2	253d4c4d-fe2b-47e1-b8b6-8a7cb7dede4c	Megan Tan	\N	\N	60192418298	\N	2025-11-28 12:53:12.331185	2025-11-28 12:53:12.331185
363	2	1491b706-6305-44fe-966c-7c96144e61b0	Hewson Tan	\N	\N	60189861002	\N	2025-11-28 12:54:35.623747	2025-11-28 12:54:35.623747
364	2	0dfd7b29-5a3c-49ea-8190-648a91f7f534	Law Whye Hoe	\N	\N	60128833128	\N	2025-11-28 12:54:43.898782	2025-11-28 12:54:43.898782
365	2	a0d03ea8-3f7e-41ca-b65a-4414e3ce0d46	Te Chin Yong	\N	\N	601120169027	\N	2025-11-28 12:54:47.601045	2025-11-28 12:54:47.601045
366	2	22d18b62-7b8c-4d0a-bed6-f6694731334a	Ang Kian Tuck	\N	\N	60192629377	\N	2025-11-28 12:55:06.379599	2025-11-28 12:55:06.379599
367	2	d3a57b3f-1dd3-4280-a99b-8726c2153295	Lance Wong Wei Xiang	\N	\N	60122929982	\N	2025-11-28 12:55:10.223469	2025-11-28 12:55:10.223469
368	2	5815ceed-ebd4-4170-b3e6-ad7ef3fab1c8	Sharon Shim	\N	\N	60135418628	\N	2025-11-28 12:55:11.362713	2025-11-28 12:55:11.362713
369	2	d5147ca3-fa2d-4e7c-85c1-1646f5f5a4d7	Win Lee	\N	\N	60122799708	\N	2025-11-28 12:55:13.273549	2025-11-28 12:55:13.273549
370	2	5b30149a-8878-4cc2-88a2-f4fc79db651e	Olivia Tan	\N	\N	60165902185	\N	2025-11-28 12:55:13.890682	2025-11-28 12:55:13.890682
371	2	00eb325f-17d3-4019-9fcf-a9f0a5c1f86b	Leonm Tang	\N	\N	60102686780	\N	2025-11-28 12:55:15.122784	2025-11-28 12:55:15.122784
372	2	0b3a1cf6-7d44-4e25-b16a-6818130e4e0b	Lew Shi Ern	\N	\N	60109038074	\N	2025-11-28 12:55:20.459637	2025-11-28 12:55:20.459637
373	2	7dabcad6-ac70-4753-9e02-efe4385d1231	Jeremy Kang	\N	\N	60164098583	\N	2025-11-28 12:55:20.582771	2025-11-28 12:55:20.582771
374	2	bae31119-61ff-4ae7-a7b9-f456f7ad2d37	Ling Zhi Yong	\N	\N	60162632933	\N	2025-11-28 12:55:26.570312	2025-11-28 12:55:26.570312
375	2	352c5848-568c-491c-90fb-4e97055dce63	Desmond Soon	\N	\N	60182332377	\N	2025-11-28 12:55:27.201478	2025-11-28 12:55:27.201478
376	2	c998f2fa-fa78-4de0-ac8a-94844d9bec47	Ooi Boon Hao	\N	\N	60164730777	\N	2025-11-28 12:55:29.758009	2025-11-28 12:55:29.758009
377	2	df009f01-e1e6-4c71-b58b-e99999ff9f78	Hong Lim	\N	\N	60134502000	\N	2025-11-28 12:55:29.803629	2025-11-28 12:55:29.803629
378	2	a57c1bd2-1a04-4dd6-b0b8-b456408cb4e7	Izz Afiq	\N	\N	60123989409	\N	2025-11-28 12:55:30.345507	2025-11-28 12:55:30.345507
379	2	b1039d26-35f7-4196-b956-bd1fc6f02359	Kenny Lau	\N	\N	60163259398	\N	2025-11-28 12:55:30.853923	2025-11-28 12:55:30.853923
380	2	3c625610-5321-4391-b02e-05aa21009eca	Eugene Phuah Weiwen	\N	\N	60124996726	\N	2025-11-28 12:55:32.672686	2025-11-28 12:55:32.672686
381	2	161160a3-6475-4049-90fa-174bf81b2f3f	Aaron Chong	\N	\N	60122503200	\N	2025-11-28 12:55:33.659163	2025-11-28 12:55:33.659163
382	2	52a247e4-5ef9-40cc-8ded-ad86faa1e03b	Lau Lay Yong	\N	\N	60123653365	\N	2025-11-28 12:55:39.215613	2025-11-28 12:55:39.215613
383	2	adf81191-c2a5-4f90-9b61-c2bda05d414c	Alvin	\N	\N	60124122325	\N	2025-11-28 12:55:39.294504	2025-11-28 12:55:39.294504
384	2	cabd6d6c-7071-4533-a6dc-fe5c4aada0d4	Lee Qing Yi	\N	\N	60165348157	\N	2025-11-28 12:55:41.546989	2025-11-28 12:55:41.546989
385	2	a7b83e98-3f3d-48ca-aec1-0ffd56802bfd	Master Chris Leong	\N	\N	60193163122	\N	2025-11-28 12:55:44.881555	2025-11-28 12:55:44.881555
386	2	cce4664f-855b-46d5-bf23-50a690a9a2e8	Jimmy Yen C.k	\N	\N	60169038593	\N	2025-11-28 12:55:45.312188	2025-11-28 12:55:45.312188
387	2	6d76b5e5-c9dc-426d-8a54-001680ca7946	Ng Kin Lam	\N	\N	60123321776	\N	2025-11-28 12:55:46.323007	2025-11-28 12:55:46.323007
388	2	b3b34db4-34c2-4d4e-9f5e-a3d8c876906f	Law Chai Yoke	\N	\N	60172217288	\N	2025-11-28 12:55:46.390144	2025-11-28 12:55:46.390144
389	2	a974adc8-dd6a-4d49-9c99-7bb94c00c29d	Loh Sheng Jiet	\N	\N	60169529596	\N	2025-11-28 12:55:51.58297	2025-11-28 12:55:51.58297
390	2	5950e50b-af4d-4e8e-89f3-46a4d2b77b01	Bernice Chin-langshaw	\N	\N	60128852901	\N	2025-11-28 12:55:52.223086	2025-11-28 12:55:52.223086
391	2	b564f93d-1bd9-48b1-9b5b-496ef70193dd	Tasha Bashah	\N	\N	60176065501	\N	2025-11-28 12:56:07.647897	2025-11-28 12:56:07.647897
392	2	78055557-8810-4b07-8c0d-c7447e72a315	Wong Zhen Bang	\N	\N	60168159588	\N	2025-11-28 12:56:08.392971	2025-11-28 12:56:08.392971
393	2	df9f4eda-4538-43b6-a76e-73e5a5d72821	Lim Meng Piew	\N	\N	60133679019	\N	2025-11-28 12:56:08.741298	2025-11-28 12:56:08.741298
394	2	e698f9a8-8a2d-4faf-a4eb-b99e0d3c1240	Carmen Toh	\N	\N	60193228625	\N	2025-11-28 12:56:16.904669	2025-11-28 12:56:16.904669
395	2	aef049da-8659-404b-8329-f9f80dec1ccc	Yeo Sze Ying	\N	\N	60182038664	\N	2025-11-28 12:56:21.434698	2025-11-28 12:56:21.434698
396	2	28459c7a-8451-43d5-9d8c-00053c8bbb1a	Jimmi Yeo Chin Yee	\N	\N	60133428261	\N	2025-11-28 12:56:21.452034	2025-11-28 12:56:21.452034
397	2	9e9cef2e-4d42-47dd-8ff9-8c2cc74d6a9d	Foo Jia Xi	\N	\N	601118738199	\N	2025-11-28 12:56:22.826613	2025-11-28 12:56:22.826613
398	2	5dd7efdb-f03e-4251-b34a-e4a3732cd096	Ho Lou Shin	\N	\N	60122092080	\N	2025-11-28 12:56:23.992972	2025-11-28 12:56:23.992972
399	2	4a50252c-cdfe-4282-885f-9131deb5d489	Chiam Yee Seng	\N	\N	60166511365	\N	2025-11-28 12:56:28.803919	2025-11-28 12:56:28.803919
400	2	6e64f9ed-3e49-485c-a201-b2b6b3ecc7b7	Dato Lee Ngai Mun	\N	\N	60163112187	\N	2025-11-28 12:56:30.204616	2025-11-28 12:56:30.204616
401	2	cf12f27e-d7c8-4733-a3e8-2323911f42aa	Leong Pei Xin	\N	\N	601157287687	\N	2025-11-28 12:56:32.359163	2025-11-28 12:56:32.359163
402	2	1d513b92-e432-4611-b8d8-47d8b8ae0885	Leong Kar Wey	\N	\N	60177172077	\N	2025-11-28 12:56:33.900119	2025-11-28 12:56:33.900119
403	2	6cc6cdcd-15e3-4307-b6c3-9a4bdc6d8ae6	Yang	\N	\N	60166991232	\N	2025-11-28 12:57:06.401633	2025-11-28 12:57:06.401633
404	2	cb1fe7ee-00b6-4cd9-92a1-d97adf55dcf8	Tee Soon Joo	\N	\N	601173643931	\N	2025-11-28 12:57:42.633821	2025-11-28 12:57:42.633821
405	2	11733940-0785-4e4b-a440-b04abdff3e90	Chang Kai Deng	\N	\N	60196008333	\N	2025-11-28 12:58:07.35993	2025-11-28 12:58:07.35993
406	2	932b75be-639b-48a6-a58e-3ca81ac1cd1b	Tong Kim Hong	\N	\N	60167412569	\N	2025-11-28 12:58:55.09454	2025-11-28 12:58:55.09454
407	2	8c058216-cfc6-42fe-b6b0-89b2a6962cf0	Abdul Ashraff	\N	\N	60176898445	\N	2025-11-28 13:02:27.148051	2025-11-28 13:02:27.148051
408	2	3d74dd2c-bab6-40b5-bd97-01386da706be	Gonley Lee	\N	\N	60164160309	\N	2025-11-28 13:02:28.295755	2025-11-28 13:02:28.295755
409	2	95ff78f2-f9f2-41ae-95c5-648e53777555	Matchy Ma	\N	\N	60162130522	\N	2025-11-28 13:03:05.608912	2025-11-28 13:03:05.608912
410	2	39f58080-1d7c-4371-938b-19f07b16fdad	Paresh	\N	\N	60175039835	\N	2025-11-28 13:09:20.976451	2025-11-28 13:09:20.976451
411	2	ade018a0-241a-4d4d-85c8-64358850e806	See Teik Chun	\N	\N	601126456239	\N	2025-11-28 13:26:51.862226	2025-11-28 13:26:51.862226
412	2	6fd1bd6d-7d31-44b8-8128-e930b6de22a0	Lee Yong Wee	\N	\N	60162276188	\N	2025-11-28 13:36:41.997432	2025-11-28 13:36:41.997432
413	2	6d88ebdd-5403-423c-b495-29f287c48d01	Mieko Lee	\N	\N	60165276672	\N	2025-11-28 13:37:17.260752	2025-11-28 13:37:17.260752
414	2	431eb29e-a9b2-4100-af35-9594cf178662	Jasmie Lee	\N	\N	60134599854	\N	2025-11-28 13:37:34.410372	2025-11-28 13:37:34.410372
415	2	294dff94-4436-4f3c-b294-da85ab590aa4	Cyrus Cheoj	\N	\N	60169965987	\N	2025-11-28 13:39:52.373899	2025-11-28 13:39:52.373899
416	2	7e7ef4e6-0322-4ec0-8fad-9915b39ecc43	Kevin Woo	\N	\N	60102053952	\N	2025-11-28 13:40:11.136256	2025-11-28 13:40:11.136256
417	2	2b6f568f-befe-47e5-ba2b-815b02e9149f	Jaff Low	\N	\N	60124713828	\N	2025-11-28 13:42:41.500313	2025-11-28 13:42:41.500313
418	2	b69d2b85-43bd-4fb8-9ac4-86b3a75efe76	James Wong Ing Chieng	\N	\N	60122494919	\N	2025-11-28 13:46:39.823693	2025-11-28 13:46:39.823693
419	2	d6ecafa7-d1b0-4684-b6ac-1c664229c393	Maxwell Lim	\N	\N	60162206570	\N	2025-11-28 13:47:05.325496	2025-11-28 13:47:05.325496
420	2	77b6695a-c1b8-40b2-b443-797690111270	Aaron Lim	\N	\N	60123638184	\N	2025-11-28 14:02:11.221815	2025-11-28 14:02:11.221815
\.


--
-- Data for Name: voucher_redemption_logs; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.voucher_redemption_logs (id, voucher_id, redeemer_staff_id, redemption_timestamp, redemption_location, redemption_status, transaction_gross_amount, discount_applied_value, transaction_net_amount, cancellation_timestamp, cancellation_reason, notes, created_at, updated_at, redeemer_id, redeemer_type) FROM stdin;
1	1	33	2025-11-25 05:30:41.735258	\N	completed	0.00	0.00	0.00	\N	\N	\N	2025-11-25 05:30:41.749592	2025-11-25 05:30:41.749592	1	Visitor
2	2	35	2025-11-25 05:40:09.695897	\N	completed	198.00	98.00	100.00	\N	\N	\N	2025-11-25 05:40:09.696692	2025-11-25 05:40:09.696692	2	Visitor
\.


--
-- Data for Name: voucher_usages; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.voucher_usages (id, voucher_id, redemption_count, first_view_timestamp, created_at, updated_at, redeemer_id, redeemer_type) FROM stdin;
1	1	1	\N	2025-11-25 05:30:41.730415	2025-11-25 05:30:41.730415	1	1
2	2	1	\N	2025-11-25 05:40:09.692875	2025-11-25 05:40:09.692875	2	1
\.


--
-- Data for Name: vouchers; Type: TABLE DATA; Schema: public; Owner: lttechteam
--

COPY public.vouchers (id, title, voucher_uuid, description, vendor_id, event_id, voucher_code, start_date, end_date, start_time, end_time, total_redemption_available, redeemed_count, max_redemptions_per_user, user_role_restriction, voucher_value, created_at, updated_at, image_path, voucher_category, status, voucher_type, is_unlimited) FROM stdin;
1	Id et temporibus ve	5ebf285a-0373-47f5-b37a-4e369777e022	Qui dolorem Nam enim	33	2	\N	2025-11-23	2025-11-28	00:00:00	00:00:00	150	1	1	\N	0.00	2025-11-25 05:29:56.335711	2025-11-25 05:29:56.335711	\N	\N	0	2	f
2	Ut elit commodo lor	fee6c015-e0b2-4cd2-9400-0990dd418582	Autem ducimus eos	35	2	\N	2025-11-23	2025-11-28	00:00:00	00:00:00	290	1	1	\N	98.00	2025-11-25 05:38:55.900792	2025-11-25 05:38:55.900792	\N	\N	0	0	f
\.


--
-- Name: api_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.api_keys_id_seq', 3, true);


--
-- Name: email_verifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.email_verifications_id_seq', 22, true);


--
-- Name: event_assignments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.event_assignments_id_seq', 14, true);


--
-- Name: event_exhibition_contractors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.event_exhibition_contractors_id_seq', 1, false);


--
-- Name: event_location_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.event_location_members_id_seq', 9, true);


--
-- Name: event_locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.event_locations_id_seq', 1, true);


--
-- Name: event_vendors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.event_vendors_id_seq', 2, true);


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.events_id_seq', 3, true);


--
-- Name: exhibition_contractor_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.exhibition_contractor_profiles_id_seq', 1, false);


--
-- Name: exhibitor_kits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.exhibitor_kits_id_seq', 1, false);


--
-- Name: exhibitor_owners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.exhibitor_owners_id_seq', 1, false);


--
-- Name: exhibitor_team_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.exhibitor_team_members_id_seq', 1, false);


--
-- Name: export_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.export_logs_id_seq', 16, true);


--
-- Name: group_affiliates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.group_affiliates_id_seq', 1, false);


--
-- Name: group_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.group_members_id_seq', 1, false);


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.groups_id_seq', 1, false);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.orders_id_seq', 1, false);


--
-- Name: password_resets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.password_resets_id_seq', 3, true);


--
-- Name: ticket_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.ticket_types_id_seq', 11, true);


--
-- Name: tickets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.tickets_id_seq', 2094, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.users_id_seq', 38, true);


--
-- Name: vendor_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.vendor_profiles_id_seq', 2, true);


--
-- Name: visitor_vendor_stamps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.visitor_vendor_stamps_id_seq', 1, false);


--
-- Name: visitors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.visitors_id_seq', 420, true);


--
-- Name: voucher_redemption_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.voucher_redemption_logs_id_seq', 2, true);


--
-- Name: voucher_usages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.voucher_usages_id_seq', 2, true);


--
-- Name: vouchers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lttechteam
--

SELECT pg_catalog.setval('public.vouchers_id_seq', 2, true);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: email_verifications email_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.email_verifications
    ADD CONSTRAINT email_verifications_pkey PRIMARY KEY (id);


--
-- Name: event_assignments event_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_assignments
    ADD CONSTRAINT event_assignments_pkey PRIMARY KEY (id);


--
-- Name: event_exhibition_contractors event_exhibition_contractors_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_exhibition_contractors
    ADD CONSTRAINT event_exhibition_contractors_pkey PRIMARY KEY (id);


--
-- Name: event_location_members event_location_members_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_location_members
    ADD CONSTRAINT event_location_members_pkey PRIMARY KEY (id);


--
-- Name: event_locations event_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_locations
    ADD CONSTRAINT event_locations_pkey PRIMARY KEY (id);


--
-- Name: event_vendors event_vendors_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_vendors
    ADD CONSTRAINT event_vendors_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: exhibition_contractor_profiles exhibition_contractor_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibition_contractor_profiles
    ADD CONSTRAINT exhibition_contractor_profiles_pkey PRIMARY KEY (id);


--
-- Name: exhibitor_kits exhibitor_kits_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_kits
    ADD CONSTRAINT exhibitor_kits_pkey PRIMARY KEY (id);


--
-- Name: exhibitor_owners exhibitor_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_owners
    ADD CONSTRAINT exhibitor_owners_pkey PRIMARY KEY (id);


--
-- Name: exhibitor_team_members exhibitor_team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_team_members
    ADD CONSTRAINT exhibitor_team_members_pkey PRIMARY KEY (id);


--
-- Name: export_logs export_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.export_logs
    ADD CONSTRAINT export_logs_pkey PRIMARY KEY (id);


--
-- Name: group_affiliates group_affiliates_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_affiliates
    ADD CONSTRAINT group_affiliates_pkey PRIMARY KEY (id);


--
-- Name: group_members group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: ticket_types ticket_types_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.ticket_types
    ADD CONSTRAINT ticket_types_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vendor_profiles vendor_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vendor_profiles
    ADD CONSTRAINT vendor_profiles_pkey PRIMARY KEY (id);


--
-- Name: visitor_vendor_stamps visitor_vendor_stamps_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitor_vendor_stamps
    ADD CONSTRAINT visitor_vendor_stamps_pkey PRIMARY KEY (id);


--
-- Name: visitors visitors_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT visitors_pkey PRIMARY KEY (id);


--
-- Name: voucher_redemption_logs voucher_redemption_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_redemption_logs
    ADD CONSTRAINT voucher_redemption_logs_pkey PRIMARY KEY (id);


--
-- Name: voucher_usages voucher_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_usages
    ADD CONSTRAINT voucher_usages_pkey PRIMARY KEY (id);


--
-- Name: vouchers vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_pkey PRIMARY KEY (id);


--
-- Name: idx_on_event_location_id_member_id_fa34732f50; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX idx_on_event_location_id_member_id_fa34732f50 ON public.event_location_members USING btree (event_location_id, member_id);


--
-- Name: idx_on_exhibition_contractor_profile_id_13ae474f9f; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX idx_on_exhibition_contractor_profile_id_13ae474f9f ON public.event_exhibition_contractors USING btree (exhibition_contractor_profile_id);


--
-- Name: idx_tickets_event_email_norm; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX idx_tickets_event_email_norm ON public.tickets USING btree (event_id, attendee_email_norm) WHERE (attendee_email_norm IS NOT NULL);


--
-- Name: idx_tickets_event_phone_norm; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX idx_tickets_event_phone_norm ON public.tickets USING btree (event_id, attendee_phone_norm) WHERE (attendee_phone_norm IS NOT NULL);


--
-- Name: idx_tickets_event_type_name_norm_unique; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX idx_tickets_event_type_name_norm_unique ON public.tickets USING btree (event_id, ticket_type_id, attendee_name_norm) WHERE ((attendee_email_norm IS NULL) AND (attendee_phone_norm IS NULL));


--
-- Name: index_api_keys_on_key_hash; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_api_keys_on_key_hash ON public.api_keys USING btree (key_hash);


--
-- Name: index_api_keys_on_last_used_at; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_api_keys_on_last_used_at ON public.api_keys USING btree (last_used_at);


--
-- Name: index_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);


--
-- Name: index_email_verifications_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_email_verifications_on_user_id ON public.email_verifications USING btree (user_id);


--
-- Name: index_event_assignments_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_assignments_on_event_id ON public.event_assignments USING btree (event_id);


--
-- Name: index_event_assignments_on_event_id_and_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_event_assignments_on_event_id_and_user_id ON public.event_assignments USING btree (event_id, user_id);


--
-- Name: index_event_assignments_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_assignments_on_user_id ON public.event_assignments USING btree (user_id);


--
-- Name: index_event_exhibition_contractors_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_event_exhibition_contractors_on_event_id ON public.event_exhibition_contractors USING btree (event_id);


--
-- Name: index_event_location_members_on_event_location_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_location_members_on_event_location_id ON public.event_location_members USING btree (event_location_id);


--
-- Name: index_event_location_members_on_member_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_location_members_on_member_id ON public.event_location_members USING btree (member_id);


--
-- Name: index_event_locations_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_locations_on_event_id ON public.event_locations USING btree (event_id);


--
-- Name: index_event_locations_on_event_id_and_floor; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_locations_on_event_id_and_floor ON public.event_locations USING btree (event_id, floor);


--
-- Name: index_event_locations_on_event_id_and_name; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_event_locations_on_event_id_and_name ON public.event_locations USING btree (event_id, name);


--
-- Name: index_event_locations_on_location_details; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_locations_on_location_details ON public.event_locations USING gin (location_details);


--
-- Name: index_event_vendors_on_event_and_vendor; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_event_vendors_on_event_and_vendor ON public.event_vendors USING btree (event_id, vendor_id);


--
-- Name: index_event_vendors_on_exhibitor_owner_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_vendors_on_exhibitor_owner_id ON public.event_vendors USING btree (exhibitor_owner_id);


--
-- Name: index_event_vendors_on_type; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_vendors_on_type ON public.event_vendors USING btree (type);


--
-- Name: index_event_vendors_on_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_event_vendors_on_vendor_id ON public.event_vendors USING btree (vendor_id);


--
-- Name: index_events_on_deleted_at; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_events_on_deleted_at ON public.events USING btree (deleted_at);


--
-- Name: index_events_on_slug; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_events_on_slug ON public.events USING btree (slug);


--
-- Name: index_exhibition_contractor_profiles_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_exhibition_contractor_profiles_on_user_id ON public.exhibition_contractor_profiles USING btree (user_id);


--
-- Name: index_exhibitor_kits_on_event_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_exhibitor_kits_on_event_vendor_id ON public.exhibitor_kits USING btree (event_vendor_id);


--
-- Name: index_exhibitor_owners_on_name; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_exhibitor_owners_on_name ON public.exhibitor_owners USING btree (name);


--
-- Name: index_exhibitor_team_members_on_exhibitor_kit_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_exhibitor_team_members_on_exhibitor_kit_id ON public.exhibitor_team_members USING btree (exhibitor_kit_id);


--
-- Name: index_export_logs_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_export_logs_on_event_id ON public.export_logs USING btree (event_id);


--
-- Name: index_export_logs_on_type_and_created_at; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_export_logs_on_type_and_created_at ON public.export_logs USING btree (type, created_at);


--
-- Name: index_group_affiliates_on_group_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_group_affiliates_on_group_id ON public.group_affiliates USING btree (group_id);


--
-- Name: index_group_affiliates_on_group_id_and_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_group_affiliates_on_group_id_and_vendor_id ON public.group_affiliates USING btree (group_id, vendor_id);


--
-- Name: index_group_affiliates_on_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_group_affiliates_on_vendor_id ON public.group_affiliates USING btree (vendor_id);


--
-- Name: index_group_members_on_group_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_group_members_on_group_id ON public.group_members USING btree (group_id);


--
-- Name: index_group_members_on_group_id_and_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_group_members_on_group_id_and_user_id ON public.group_members USING btree (group_id, user_id);


--
-- Name: index_group_members_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_group_members_on_user_id ON public.group_members USING btree (user_id);


--
-- Name: index_groups_on_name; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_groups_on_name ON public.groups USING btree (name);


--
-- Name: index_password_resets_on_expires_at; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_password_resets_on_expires_at ON public.password_resets USING btree (expires_at);


--
-- Name: index_password_resets_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_password_resets_on_user_id ON public.password_resets USING btree (user_id);


--
-- Name: index_ticket_types_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_ticket_types_on_event_id ON public.ticket_types USING btree (event_id);


--
-- Name: index_ticket_types_on_event_id_and_status; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_ticket_types_on_event_id_and_status ON public.ticket_types USING btree (event_id, status);


--
-- Name: index_tickets_on_deleted_at; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_tickets_on_deleted_at ON public.tickets USING btree (deleted_at);


--
-- Name: index_tickets_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_tickets_on_event_id ON public.tickets USING btree (event_id);


--
-- Name: index_tickets_on_event_id_and_status; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_tickets_on_event_id_and_status ON public.tickets USING btree (event_id, status);


--
-- Name: index_tickets_on_public_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_tickets_on_public_id ON public.tickets USING btree (public_id);


--
-- Name: index_tickets_on_scanned_by_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_tickets_on_scanned_by_id ON public.tickets USING btree (scanned_by_id);


--
-- Name: index_tickets_on_ticket_type_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_tickets_on_ticket_type_id ON public.tickets USING btree (ticket_type_id);


--
-- Name: index_tickets_on_user_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_tickets_on_user_id ON public.tickets USING btree (user_id);


--
-- Name: index_users_on_created_by_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_users_on_created_by_id ON public.users USING btree (created_by_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_jti; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_users_on_jti ON public.users USING btree (jti);


--
-- Name: index_users_on_status; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_users_on_status ON public.users USING btree (status);


--
-- Name: index_vendor_profiles_on_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_vendor_profiles_on_vendor_id ON public.vendor_profiles USING btree (vendor_id);


--
-- Name: index_visitor_vendor_stamps_on_event_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_visitor_vendor_stamps_on_event_vendor_id ON public.visitor_vendor_stamps USING btree (event_vendor_id);


--
-- Name: index_visitor_vendor_stamps_on_visitor_and_event_vendor; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_visitor_vendor_stamps_on_visitor_and_event_vendor ON public.visitor_vendor_stamps USING btree (visitor_id, event_vendor_id);


--
-- Name: index_visitor_vendor_stamps_on_visitor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_visitor_vendor_stamps_on_visitor_id ON public.visitor_vendor_stamps USING btree (visitor_id);


--
-- Name: index_visitors_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_visitors_on_event_id ON public.visitors USING btree (event_id);


--
-- Name: index_visitors_on_public_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE UNIQUE INDEX index_visitors_on_public_id ON public.visitors USING btree (public_id);


--
-- Name: index_voucher_redemption_logs_on_redeemer; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_voucher_redemption_logs_on_redeemer ON public.voucher_redemption_logs USING btree (redeemer_type, redeemer_id);


--
-- Name: index_voucher_redemption_logs_on_redeemer_staff_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_voucher_redemption_logs_on_redeemer_staff_id ON public.voucher_redemption_logs USING btree (redeemer_staff_id);


--
-- Name: index_voucher_redemption_logs_on_voucher_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_voucher_redemption_logs_on_voucher_id ON public.voucher_redemption_logs USING btree (voucher_id);


--
-- Name: index_voucher_usages_on_redeemer_type_and_redeemer_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_voucher_usages_on_redeemer_type_and_redeemer_id ON public.voucher_usages USING btree (redeemer_type, redeemer_id);


--
-- Name: index_voucher_usages_on_voucher_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_voucher_usages_on_voucher_id ON public.voucher_usages USING btree (voucher_id);


--
-- Name: index_vouchers_on_event_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_vouchers_on_event_id ON public.vouchers USING btree (event_id);


--
-- Name: index_vouchers_on_status; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_vouchers_on_status ON public.vouchers USING btree (status);


--
-- Name: index_vouchers_on_vendor_id; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_vouchers_on_vendor_id ON public.vouchers USING btree (vendor_id);


--
-- Name: index_vouchers_on_voucher_code; Type: INDEX; Schema: public; Owner: lttechteam
--

CREATE INDEX index_vouchers_on_voucher_code ON public.vouchers USING btree (voucher_code);


--
-- Name: event_location_members fk_rails_0021a72ace; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_location_members
    ADD CONSTRAINT fk_rails_0021a72ace FOREIGN KEY (event_location_id) REFERENCES public.event_locations(id);


--
-- Name: event_vendors fk_rails_06de8b8b1e; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_vendors
    ADD CONSTRAINT fk_rails_06de8b8b1e FOREIGN KEY (exhibitor_owner_id) REFERENCES public.exhibitor_owners(id);


--
-- Name: vouchers fk_rails_0b7a43393a; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT fk_rails_0b7a43393a FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: event_vendors fk_rails_1b947fb02a; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_vendors
    ADD CONSTRAINT fk_rails_1b947fb02a FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: group_affiliates fk_rails_1e7d49e80f; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_affiliates
    ADD CONSTRAINT fk_rails_1e7d49e80f FOREIGN KEY (vendor_id) REFERENCES public.users(id);


--
-- Name: exhibitor_kits fk_rails_1f4627eeb5; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_kits
    ADD CONSTRAINT fk_rails_1f4627eeb5 FOREIGN KEY (event_vendor_id) REFERENCES public.event_vendors(id);


--
-- Name: event_assignments fk_rails_25379529a4; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_assignments
    ADD CONSTRAINT fk_rails_25379529a4 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: visitor_vendor_stamps fk_rails_2c9f249d35; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitor_vendor_stamps
    ADD CONSTRAINT fk_rails_2c9f249d35 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: api_keys fk_rails_32c28d0dc2; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_32c28d0dc2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: voucher_redemption_logs fk_rails_3ef63e94b7; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_redemption_logs
    ADD CONSTRAINT fk_rails_3ef63e94b7 FOREIGN KEY (voucher_id) REFERENCES public.vouchers(id);


--
-- Name: ticket_types fk_rails_3f5bd3dab9; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.ticket_types
    ADD CONSTRAINT fk_rails_3f5bd3dab9 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: users fk_rails_45307c95a3; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_45307c95a3 FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vouchers fk_rails_46f07488a4; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT fk_rails_46f07488a4 FOREIGN KEY (vendor_id) REFERENCES public.users(id);


--
-- Name: tickets fk_rails_4def87ea62; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_4def87ea62 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: event_vendors fk_rails_521233af1d; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_vendors
    ADD CONSTRAINT fk_rails_521233af1d FOREIGN KEY (vendor_id) REFERENCES public.users(id);


--
-- Name: password_resets fk_rails_526379cd99; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.password_resets
    ADD CONSTRAINT fk_rails_526379cd99 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tickets fk_rails_538a036fb9; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_538a036fb9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: event_exhibition_contractors fk_rails_54a582ba3c; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_exhibition_contractors
    ADD CONSTRAINT fk_rails_54a582ba3c FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: visitors fk_rails_57c14b96b5; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_57c14b96b5 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: event_locations fk_rails_7c5d68f3b5; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_locations
    ADD CONSTRAINT fk_rails_7c5d68f3b5 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: exhibitor_team_members fk_rails_8227d42dbb; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibitor_team_members
    ADD CONSTRAINT fk_rails_8227d42dbb FOREIGN KEY (exhibitor_kit_id) REFERENCES public.exhibitor_kits(id);


--
-- Name: voucher_redemption_logs fk_rails_86daed8b2a; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_redemption_logs
    ADD CONSTRAINT fk_rails_86daed8b2a FOREIGN KEY (redeemer_staff_id) REFERENCES public.users(id);


--
-- Name: tickets fk_rails_89217f3a4e; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_89217f3a4e FOREIGN KEY (ticket_type_id) REFERENCES public.ticket_types(id);


--
-- Name: tickets fk_rails_9112a686fd; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_9112a686fd FOREIGN KEY (scanned_by_id) REFERENCES public.users(id);


--
-- Name: exhibition_contractor_profiles fk_rails_9391f9a9de; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.exhibition_contractor_profiles
    ADD CONSTRAINT fk_rails_9391f9a9de FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: event_location_members fk_rails_abf9da2702; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_location_members
    ADD CONSTRAINT fk_rails_abf9da2702 FOREIGN KEY (member_id) REFERENCES public.users(id);


--
-- Name: group_affiliates fk_rails_b74fdb3923; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_affiliates
    ADD CONSTRAINT fk_rails_b74fdb3923 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: group_members fk_rails_bb66f6bca8; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT fk_rails_bb66f6bca8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: email_verifications fk_rails_bd5a6564f8; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.email_verifications
    ADD CONSTRAINT fk_rails_bd5a6564f8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: vendor_profiles fk_rails_cb003eca82; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.vendor_profiles
    ADD CONSTRAINT fk_rails_cb003eca82 FOREIGN KEY (vendor_id) REFERENCES public.users(id);


--
-- Name: voucher_usages fk_rails_cc63c52f55; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.voucher_usages
    ADD CONSTRAINT fk_rails_cc63c52f55 FOREIGN KEY (voucher_id) REFERENCES public.vouchers(id);


--
-- Name: event_exhibition_contractors fk_rails_e14486d05b; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_exhibition_contractors
    ADD CONSTRAINT fk_rails_e14486d05b FOREIGN KEY (exhibition_contractor_profile_id) REFERENCES public.exhibition_contractor_profiles(id);


--
-- Name: event_assignments fk_rails_e217ffe9b3; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.event_assignments
    ADD CONSTRAINT fk_rails_e217ffe9b3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: visitor_vendor_stamps fk_rails_e96d5cc6e7; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.visitor_vendor_stamps
    ADD CONSTRAINT fk_rails_e96d5cc6e7 FOREIGN KEY (event_vendor_id) REFERENCES public.event_vendors(id);


--
-- Name: group_members fk_rails_e9fdb70ec5; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT fk_rails_e9fdb70ec5 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: export_logs fk_rails_faf5ce98af; Type: FK CONSTRAINT; Schema: public; Owner: lttechteam
--

ALTER TABLE ONLY public.export_logs
    ADD CONSTRAINT fk_rails_faf5ce98af FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- PostgreSQL database dump complete
--

\unrestrict p4f8cbVVW63YZ4ZncntFEDpIauBmR7NjJB1a4GaS4MvdCUtKWyJwEXcv7B2mEMq
