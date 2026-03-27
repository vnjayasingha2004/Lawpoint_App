--
-- PostgreSQL database dump
--



-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-03-22 02:57:27

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

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

--CREATE SCHEMA public;


--ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

--COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 874 (class 1247 OID 24618)
-- Name: AppointmentStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."AppointmentStatus" AS ENUM (
    'SCHEDULED',
    'COMPLETED',
    'CANCELLED'
);


ALTER TYPE public."AppointmentStatus" OWNER TO postgres;

--
-- TOC entry 868 (class 1247 OID 24603)
-- Name: Role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."Role" AS ENUM (
    'CLIENT',
    'LAWYER',
    'ADMIN'
);


ALTER TYPE public."Role" OWNER TO postgres;

--
-- TOC entry 871 (class 1247 OID 24610)
-- Name: VerificationStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."VerificationStatus" AS ENUM (
    'PENDING',
    'APPROVED',
    'REJECTED'
);


ALTER TYPE public."VerificationStatus" OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 223 (class 1259 OID 24676)
-- Name: Appointment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Appointment" (
    id text NOT NULL,
    "clientId" text NOT NULL,
    "lawyerId" text NOT NULL,
    "startTime" timestamp(3) without time zone NOT NULL,
    "endTime" timestamp(3) without time zone NOT NULL,
    status public."AppointmentStatus" DEFAULT 'SCHEDULED'::public."AppointmentStatus" NOT NULL,
    "videoSessionId" text,
    "paymentStatus" text DEFAULT 'PENDING'::text NOT NULL,
    amount double precision NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "gatewayTransactionId" text,
    currency text DEFAULT 'LKR'::text NOT NULL,
    "paidAt" timestamp(3) without time zone
);


ALTER TABLE public."Appointment" OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 24956)
-- Name: AuditLog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."AuditLog" (
    id text NOT NULL,
    "actorUserId" text,
    "eventType" text NOT NULL,
    "targetType" text,
    "targetId" text,
    "ipAddress" text,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public."AuditLog" OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 24663)
-- Name: AvailabilitySlot; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."AvailabilitySlot" (
    id text NOT NULL,
    "lawyerId" text NOT NULL,
    "startTime" time without time zone NOT NULL,
    "endTime" time without time zone NOT NULL,
    "isBooked" boolean DEFAULT false NOT NULL,
    "dayOfWeek" integer NOT NULL
);


ALTER TABLE public."AvailabilitySlot" OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 24724)
-- Name: Case; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Case" (
    id text NOT NULL,
    "clientId" text NOT NULL,
    "lawyerId" text NOT NULL,
    title text NOT NULL,
    description text,
    status text DEFAULT 'OPEN'::text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Case" OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 24740)
-- Name: CaseUpdate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."CaseUpdate" (
    id text NOT NULL,
    "caseId" text NOT NULL,
    title text NOT NULL,
    description text,
    "postedById" text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "hearingDate" timestamp(3) without time zone
);


ALTER TABLE public."CaseUpdate" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 24639)
-- Name: ClientProfile; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ClientProfile" (
    id text NOT NULL,
    "userId" text NOT NULL,
    "firstName" text NOT NULL,
    "lastName" text NOT NULL
);


ALTER TABLE public."ClientProfile" OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 25412)
-- Name: ConversationKeyEnvelope; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ConversationKeyEnvelope" (
    id uuid NOT NULL,
    "conversationId" text NOT NULL,
    "clientUserId" uuid NOT NULL,
    "lawyerUserId" uuid NOT NULL,
    algorithm text NOT NULL,
    "clientWrappedKey" text NOT NULL,
    "lawyerWrappedKey" text NOT NULL,
    "createdAt" timestamp with time zone NOT NULL,
    "updatedAt" timestamp with time zone NOT NULL
);


ALTER TABLE public."ConversationKeyEnvelope" OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 24753)
-- Name: DeviceToken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."DeviceToken" (
    id text NOT NULL,
    "userId" text NOT NULL,
    token text NOT NULL,
    "deviceOs" text
);


ALTER TABLE public."DeviceToken" OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 24709)
-- Name: Document; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Document" (
    id text NOT NULL,
    "clientId" text NOT NULL,
    name text NOT NULL,
    "fileUrl" text NOT NULL,
    "sharedWith" text[],
    "isEncrypted" boolean DEFAULT true NOT NULL,
    "uploadedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "storageKey" text,
    "mimeType" text,
    "sizeBytes" bigint,
    checksum text,
    "updatedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    classification text DEFAULT 'NORMAL'::text NOT NULL,
    "secretCategory" text,
    "redactionStatus" text DEFAULT 'NOT_REQUIRED'::text NOT NULL,
    "redactedStorageKey" text,
    "redactionSummary" jsonb,
    "redactionReviewedAt" timestamp with time zone,
    "redactionReviewedByUserId" text,
    "manualShareApprovedAt" timestamp with time zone,
    "manualShareApprovedByUserId" text
);


ALTER TABLE public."Document" OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 24994)
-- Name: EmailVerificationCode; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."EmailVerificationCode" (
    id text NOT NULL,
    "userId" text NOT NULL,
    code text NOT NULL,
    "expiresAt" timestamp with time zone NOT NULL,
    "usedAt" timestamp with time zone,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public."EmailVerificationCode" OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 24650)
-- Name: LawyerProfile; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."LawyerProfile" (
    id text NOT NULL,
    "userId" text NOT NULL,
    "firstName" text NOT NULL,
    "lastName" text NOT NULL,
    specializations text[],
    languages text[],
    district text,
    fees double precision,
    bio text,
    "verificationStatus" public."VerificationStatus" DEFAULT 'PENDING'::public."VerificationStatus" NOT NULL,
    "enrolmentNumber" text,
    "baslId" text,
    "submittedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "verificationReason" text,
    "verificationDecidedAt" timestamp(3) without time zone,
    "verificationDecidedBy" text,
    "enrolmentNumberCiphertext" text,
    "enrolmentNumberLookupHash" text,
    "baslIdCiphertext" text,
    "baslIdLookupHash" text
);


ALTER TABLE public."LawyerProfile" OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 24696)
-- Name: Message; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Message" (
    id text NOT NULL,
    "senderId" text NOT NULL,
    "receiverId" text NOT NULL,
    content text NOT NULL,
    "caseId" text,
    "attachmentUrl" text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    nonce text,
    "contentCiphertext" text,
    "contentEncryptionVersion" integer,
    "messageEncoding" text,
    "clientCiphertext" text,
    "clientNonce" text
);


ALTER TABLE public."Message" OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 24763)
-- Name: Notification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Notification" (
    id text NOT NULL,
    "userId" text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    type text NOT NULL,
    "isRead" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "readAt" timestamp(3) without time zone,
    data jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public."Notification" OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 24938)
-- Name: PasswordResetCode; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."PasswordResetCode" (
    id text NOT NULL,
    "userId" text NOT NULL,
    code text NOT NULL,
    "expiresAt" timestamp with time zone NOT NULL,
    "usedAt" timestamp with time zone,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public."PasswordResetCode" OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 24972)
-- Name: RefreshToken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."RefreshToken" (
    id text NOT NULL,
    "userId" text NOT NULL,
    "tokenHash" text NOT NULL,
    "expiresAt" timestamp with time zone NOT NULL,
    "revokedAt" timestamp with time zone,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public."RefreshToken" OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 24625)
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    id text NOT NULL,
    email text NOT NULL,
    phone text,
    "passwordHash" text NOT NULL,
    role public."Role" NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "isVerified" boolean DEFAULT false NOT NULL,
    "emailCiphertext" text,
    "emailLookupHash" text,
    "phoneCiphertext" text,
    "phoneLookupHash" text,
    "chatPublicKey" text,
    "chatKeyVersion" integer DEFAULT 1
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 25430)
-- Name: knowledge_articles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.knowledge_articles (
    id text NOT NULL,
    topic text NOT NULL,
    language text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    published_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.knowledge_articles OWNER TO postgres;

--
-- TOC entry 4974 (class 2606 OID 24695)
-- Name: Appointment Appointment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_pkey" PRIMARY KEY (id);


--
-- TOC entry 5000 (class 2606 OID 24966)
-- Name: AuditLog AuditLog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."AuditLog"
    ADD CONSTRAINT "AuditLog_pkey" PRIMARY KEY (id);


--
-- TOC entry 4972 (class 2606 OID 24675)
-- Name: AvailabilitySlot AvailabilitySlot_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."AvailabilitySlot"
    ADD CONSTRAINT "AvailabilitySlot_pkey" PRIMARY KEY (id);


--
-- TOC entry 4989 (class 2606 OID 24752)
-- Name: CaseUpdate CaseUpdate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CaseUpdate"
    ADD CONSTRAINT "CaseUpdate_pkey" PRIMARY KEY (id);


--
-- TOC entry 4986 (class 2606 OID 24739)
-- Name: Case Case_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Case"
    ADD CONSTRAINT "Case_pkey" PRIMARY KEY (id);


--
-- TOC entry 4963 (class 2606 OID 24649)
-- Name: ClientProfile ClientProfile_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ClientProfile"
    ADD CONSTRAINT "ClientProfile_pkey" PRIMARY KEY (id);


--
-- TOC entry 5008 (class 2606 OID 25429)
-- Name: ConversationKeyEnvelope ConversationKeyEnvelope_conversationId_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ConversationKeyEnvelope"
    ADD CONSTRAINT "ConversationKeyEnvelope_conversationId_key" UNIQUE ("conversationId");


--
-- TOC entry 5010 (class 2606 OID 25427)
-- Name: ConversationKeyEnvelope ConversationKeyEnvelope_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ConversationKeyEnvelope"
    ADD CONSTRAINT "ConversationKeyEnvelope_pkey" PRIMARY KEY (id);


--
-- TOC entry 4991 (class 2606 OID 24762)
-- Name: DeviceToken DeviceToken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DeviceToken"
    ADD CONSTRAINT "DeviceToken_pkey" PRIMARY KEY (id);


--
-- TOC entry 4981 (class 2606 OID 24723)
-- Name: Document Document_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Document"
    ADD CONSTRAINT "Document_pkey" PRIMARY KEY (id);


--
-- TOC entry 5006 (class 2606 OID 25006)
-- Name: EmailVerificationCode EmailVerificationCode_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EmailVerificationCode"
    ADD CONSTRAINT "EmailVerificationCode_pkey" PRIMARY KEY (id);


--
-- TOC entry 4966 (class 2606 OID 24662)
-- Name: LawyerProfile LawyerProfile_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."LawyerProfile"
    ADD CONSTRAINT "LawyerProfile_pkey" PRIMARY KEY (id);


--
-- TOC entry 4976 (class 2606 OID 24708)
-- Name: Message Message_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Message"
    ADD CONSTRAINT "Message_pkey" PRIMARY KEY (id);


--
-- TOC entry 4994 (class 2606 OID 24778)
-- Name: Notification Notification_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Notification"
    ADD CONSTRAINT "Notification_pkey" PRIMARY KEY (id);


--
-- TOC entry 4998 (class 2606 OID 24950)
-- Name: PasswordResetCode PasswordResetCode_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PasswordResetCode"
    ADD CONSTRAINT "PasswordResetCode_pkey" PRIMARY KEY (id);


--
-- TOC entry 5002 (class 2606 OID 24984)
-- Name: RefreshToken RefreshToken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_pkey" PRIMARY KEY (id);


--
-- TOC entry 5004 (class 2606 OID 24986)
-- Name: RefreshToken RefreshToken_tokenHash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_tokenHash_key" UNIQUE ("tokenHash");


--
-- TOC entry 4959 (class 2606 OID 24638)
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- TOC entry 5012 (class 2606 OID 25443)
-- Name: knowledge_articles knowledge_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.knowledge_articles
    ADD CONSTRAINT knowledge_articles_pkey PRIMARY KEY (id);


--
-- TOC entry 4987 (class 1259 OID 25302)
-- Name: CaseUpdate_caseId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "CaseUpdate_caseId_createdAt_idx" ON public."CaseUpdate" USING btree ("caseId", "createdAt");


--
-- TOC entry 4983 (class 1259 OID 25300)
-- Name: Case_clientId_updatedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Case_clientId_updatedAt_idx" ON public."Case" USING btree ("clientId", "updatedAt" DESC);


--
-- TOC entry 4984 (class 1259 OID 25301)
-- Name: Case_lawyerId_updatedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Case_lawyerId_updatedAt_idx" ON public."Case" USING btree ("lawyerId", "updatedAt" DESC);


--
-- TOC entry 4964 (class 1259 OID 24781)
-- Name: ClientProfile_userId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ClientProfile_userId_key" ON public."ClientProfile" USING btree ("userId");


--
-- TOC entry 4992 (class 1259 OID 24783)
-- Name: DeviceToken_token_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "DeviceToken_token_key" ON public."DeviceToken" USING btree (token);


--
-- TOC entry 4979 (class 1259 OID 25298)
-- Name: Document_clientId_uploadedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Document_clientId_uploadedAt_idx" ON public."Document" USING btree ("clientId", "uploadedAt" DESC);


--
-- TOC entry 4982 (class 1259 OID 25299)
-- Name: Document_sharedWith_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Document_sharedWith_gin" ON public."Document" USING gin ("sharedWith");


--
-- TOC entry 4967 (class 1259 OID 24782)
-- Name: LawyerProfile_userId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "LawyerProfile_userId_key" ON public."LawyerProfile" USING btree ("userId");


--
-- TOC entry 4968 (class 1259 OID 25314)
-- Name: LawyerProfile_verificationStatus_submittedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "LawyerProfile_verificationStatus_submittedAt_idx" ON public."LawyerProfile" USING btree ("verificationStatus", "submittedAt" DESC);


--
-- TOC entry 4977 (class 1259 OID 25295)
-- Name: Message_receiver_sender_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Message_receiver_sender_createdAt_idx" ON public."Message" USING btree ("receiverId", "senderId", "createdAt" DESC);


--
-- TOC entry 4978 (class 1259 OID 25294)
-- Name: Message_sender_receiver_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Message_sender_receiver_createdAt_idx" ON public."Message" USING btree ("senderId", "receiverId", "createdAt" DESC);


--
-- TOC entry 4995 (class 1259 OID 25305)
-- Name: Notification_userId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Notification_userId_createdAt_idx" ON public."Notification" USING btree ("userId", "createdAt" DESC);


--
-- TOC entry 4996 (class 1259 OID 25306)
-- Name: Notification_userId_isRead_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Notification_userId_isRead_idx" ON public."Notification" USING btree ("userId", "isRead");


--
-- TOC entry 4956 (class 1259 OID 24779)
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- TOC entry 4957 (class 1259 OID 24780)
-- Name: User_phone_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "User_phone_key" ON public."User" USING btree (phone);


--
-- TOC entry 4969 (class 1259 OID 25408)
-- Name: idx_lawyer_basl_lookup_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lawyer_basl_lookup_hash ON public."LawyerProfile" USING btree ("baslIdLookupHash");


--
-- TOC entry 4970 (class 1259 OID 25407)
-- Name: idx_lawyer_enrolment_lookup_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lawyer_enrolment_lookup_hash ON public."LawyerProfile" USING btree ("enrolmentNumberLookupHash");


--
-- TOC entry 4960 (class 1259 OID 25405)
-- Name: idx_user_email_lookup_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_email_lookup_hash ON public."User" USING btree ("emailLookupHash");


--
-- TOC entry 4961 (class 1259 OID 25406)
-- Name: idx_user_phone_lookup_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_phone_lookup_hash ON public."User" USING btree ("phoneLookupHash");


--
-- TOC entry 5017 (class 2606 OID 24799)
-- Name: Appointment Appointment_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."ClientProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5018 (class 2606 OID 24804)
-- Name: Appointment Appointment_lawyerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_lawyerId_fkey" FOREIGN KEY ("lawyerId") REFERENCES public."LawyerProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5029 (class 2606 OID 24967)
-- Name: AuditLog AuditLog_actorUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."AuditLog"
    ADD CONSTRAINT "AuditLog_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES public."User"(id) ON DELETE SET NULL;


--
-- TOC entry 5016 (class 2606 OID 24794)
-- Name: AvailabilitySlot AvailabilitySlot_lawyerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."AvailabilitySlot"
    ADD CONSTRAINT "AvailabilitySlot_lawyerId_fkey" FOREIGN KEY ("lawyerId") REFERENCES public."LawyerProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5025 (class 2606 OID 24839)
-- Name: CaseUpdate CaseUpdate_caseId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CaseUpdate"
    ADD CONSTRAINT "CaseUpdate_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES public."Case"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5023 (class 2606 OID 24829)
-- Name: Case Case_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Case"
    ADD CONSTRAINT "Case_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."ClientProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5024 (class 2606 OID 24834)
-- Name: Case Case_lawyerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Case"
    ADD CONSTRAINT "Case_lawyerId_fkey" FOREIGN KEY ("lawyerId") REFERENCES public."LawyerProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5013 (class 2606 OID 24784)
-- Name: ClientProfile ClientProfile_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ClientProfile"
    ADD CONSTRAINT "ClientProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5026 (class 2606 OID 24844)
-- Name: DeviceToken DeviceToken_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DeviceToken"
    ADD CONSTRAINT "DeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5022 (class 2606 OID 24824)
-- Name: Document Document_clientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Document"
    ADD CONSTRAINT "Document_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES public."ClientProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5031 (class 2606 OID 25007)
-- Name: EmailVerificationCode EmailVerificationCode_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EmailVerificationCode"
    ADD CONSTRAINT "EmailVerificationCode_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- TOC entry 5014 (class 2606 OID 24789)
-- Name: LawyerProfile LawyerProfile_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."LawyerProfile"
    ADD CONSTRAINT "LawyerProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5015 (class 2606 OID 25309)
-- Name: LawyerProfile LawyerProfile_verificationDecidedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."LawyerProfile"
    ADD CONSTRAINT "LawyerProfile_verificationDecidedBy_fkey" FOREIGN KEY ("verificationDecidedBy") REFERENCES public."User"(id) ON DELETE SET NULL;


--
-- TOC entry 5019 (class 2606 OID 24819)
-- Name: Message Message_caseId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Message"
    ADD CONSTRAINT "Message_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES public."Case"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5020 (class 2606 OID 24814)
-- Name: Message Message_receiverId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Message"
    ADD CONSTRAINT "Message_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5021 (class 2606 OID 24809)
-- Name: Message Message_senderId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Message"
    ADD CONSTRAINT "Message_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5027 (class 2606 OID 24849)
-- Name: Notification Notification_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Notification"
    ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5028 (class 2606 OID 24951)
-- Name: PasswordResetCode PasswordResetCode_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PasswordResetCode"
    ADD CONSTRAINT "PasswordResetCode_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- TOC entry 5030 (class 2606 OID 24987)
-- Name: RefreshToken RefreshToken_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON DELETE CASCADE;



-- Completed on 2026-03-22 02:57:28

--
-- PostgreSQL database dump complete
--



