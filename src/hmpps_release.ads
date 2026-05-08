--  hmpps_release.ads
--  ===========================================================================
--  Sentence-release calculator for HM Prison and Probation Service.
--
--  Hand-authored Ada 2012 / SPARK 2014 spec demonstrating the structural-fix
--  argument made in
--   ~/ObVault/dark-factory/business/mp-briefing-pack-2026-05-05.md, section 4:
--
--     "A deterministic, replayable, signed sentence-calculation service
--      that takes inputs ONLY through canonical contracts. No free-text
--      fields. No manual cut-and-paste. No tolerated 'we know what they
--      mean' semantic overlap. ... Surfaces disagreements between input
--      systems BEFORE the release event, not at the gate."
--
--  The Owens Review (April 2026) identified the root cause of 262 wrongful
--  releases as multiple separate IT systems (court, NOMIS, OASys, Delius)
--  with subtly different definitions of fields, dates and statuses,
--  reconciled by humans at the release point under a 21% probation
--  vacancy rate (Public Accounts Committee, 4 February 2026).
--
--  The fix expressed below: each source's subject identifier is a distinct
--  Ada type. The compiler refuses to coerce a Court_Subject_Id into a
--  NOMIS_Subject_Id without explicit conversion. Cross-source agreement is
--  an explicit Records_Agree function the caller MUST invoke. The Decide
--  procedure refuses to issue a release date if Records_Agree is false.
--
--  No path exists in this program where a release is issued under
--  inconsistent inputs. The wrongful-release case is impossible at the
--  language level — the SPARK prover discharges this obligation
--  mathematically.
--
--  This expanded version (2026-05-08) extends the original demonstrator
--  with two domain refinements:
--
--    1. Calendar dates as Day_Number (relative-day-count). The
--       calculator works in integer day arithmetic; calendar formatting
--       happens at the I/O boundary (the Gnoga GUI). Avoids the
--       leap-year reasoning that would otherwise burden the prover.
--
--    2. Multi-sentence support via a bounded array of Sentence_Record
--       values, each annotated Concurrent or Consecutive. The
--       Total_Sentence_Days function aggregates: Concurrent merges
--       with the running total (max), Consecutive adds. The first
--       sentence's Kind is treated as Consecutive (initial value).
--       Bounded at Max_Sentences = 8 to keep proof tractable.
--
--  Both refinements preserve the original four structural properties.
--  See doc/SPECIFICATION.md for the prose reading and doc/AI-REVIEW.md
--  for the independent audit confirming.

package HMPPS_Release
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------
   --  Bounds — all arithmetic is finite, all bounds give the prover a
   --  closed frame for overflow proofs.
   ---------------------------------------------------------------------

   --  100 years per individual sentence quantum.
   Max_Days      : constant := 36_500;

   --  At most 8 sentences in a single composite. Real concurrent /
   --  consecutive stacks rarely exceed this; the bound keeps the
   --  recursion in Total_Sentence_Days bounded for the prover.
   Max_Sentences : constant := 8;

   --  Per-sentence durations.
   subtype Day_Count is Natural range 0 .. Max_Days;

   --  Aggregate quantities (across sentences). Up to Max_Sentences ×
   --  Max_Days = 292,000 days (~800 years) of headroom.
   subtype Aggregate_Days is Natural range 0 .. Max_Sentences * Max_Days;

   --  A calendar coordinate. The offset (epoch) is unspecified and is
   --  agreed at the I/O boundary; here Day_Number is just a relative
   --  integer count. Range admits ~2,700 years of headroom either way.
   subtype Day_Number is Natural range 0 .. 1_000_000;

   ---------------------------------------------------------------------
   --  Subject identifiers — DISTINCT TYPES per IT source.
   --
   --  These are the structural-fix load-bearing types. Without an
   --  explicit Match function, a value of one type CANNOT be silently
   --  used where another is expected.
   ---------------------------------------------------------------------

   type Court_Subject_Id  is private;
   type NOMIS_Subject_Id  is private;
   type OASys_Subject_Id  is private;
   type Delius_Subject_Id is private;

   --  Constructors — domain-specific so callers cannot accidentally
   --  build the wrong type from raw integers.
   function Court_Id  (Raw : Natural) return Court_Subject_Id;
   function NOMIS_Id  (Raw : Natural) return NOMIS_Subject_Id;
   function OASys_Id  (Raw : Natural) return OASys_Subject_Id;
   function Delius_Id (Raw : Natural) return Delius_Subject_Id;

   --  The ONLY way to compare across sources. KNOWN MODELLING SHORTCUT:
   --  the four distinct Subject_Id types collapse to a shared Natural
   --  for comparison (see private part below). Appropriate for a
   --  demonstrator. A production deployment would replace these
   --  expression-function bodies with a typed directory/translation
   --  service — Court issues a 16-digit court reference, NOMIS an
   --  internal prison number, OASys a UUID, Delius a CRN. The package
   --  shape (typed records, named Match, explicit Records_Agree) does
   --  not change; only the bodies of these three Match overloads do.
   function Match (A : Court_Subject_Id;  B : NOMIS_Subject_Id)  return Boolean
     with Global => null;
   function Match (A : Court_Subject_Id;  B : OASys_Subject_Id)  return Boolean
     with Global => null;
   function Match (A : Court_Subject_Id;  B : Delius_Subject_Id) return Boolean
     with Global => null;

   ---------------------------------------------------------------------
   --  Sentence records — the multi-sentence model.
   --
   --  A composite sentence is an ordered sequence of Sentence_Record
   --  values, each marked Concurrent (merges with running total via
   --  max) or Consecutive (adds to running total). The first sentence's
   --  Kind is ignored — it is the initial value. By convention callers
   --  set Sentences (1).Kind = Consecutive.
   --
   --  Real UK sentencing rules (HDC, ROTL, parole, ADA/RDA, lifer
   --  carve-outs, time-on-tag) are NOT modelled here. This is the
   --  discipline, not the policy.
   ---------------------------------------------------------------------

   type Sentence_Kind is (Concurrent, Consecutive);

   type Sentence_Record is record
      Kind     : Sentence_Kind;
      Duration : Day_Count;
   end record;

   subtype Sentence_Index        is Positive range 1 .. Max_Sentences;
   subtype Sentence_Length_Range is Natural  range 0 .. Max_Sentences;

   type Sentence_Array is array (Sentence_Index) of Sentence_Record;

   ---------------------------------------------------------------------
   --  Per-source records.
   ---------------------------------------------------------------------

   type Court_Record is record
      Subject   : Court_Subject_Id;
      Start_Day : Day_Number;             --  composite sentence start (JDN-like)
      Sentences : Sentence_Array;         --  Sentences (1 .. Length) is valid
      Length    : Sentence_Length_Range;  --  count of valid Sentences entries
   end record;

   type NOMIS_Record is record
      Subject          : NOMIS_Subject_Id;
      Time_Served_Days : Aggregate_Days;  --  cumulative custody from NOMIS
   end record;

   type OASys_Record is record
      Subject            : OASys_Subject_Id;
      Behaviour_Discount : Aggregate_Days;  --  good-behaviour reduction earned
      Active_Restriction : Boolean;         --  open risk-related restriction
   end record;

   type Delius_Record is record
      Subject       : Delius_Subject_Id;
      Recall_Active : Boolean;              --  open recall to custody
   end record;

   ---------------------------------------------------------------------
   --  Total sentence days — aggregates Court.Sentences (1 .. Length).
   --  Concurrent: max with running total. Consecutive: add to total.
   --  First sentence's Kind ignored (used as initial value).
   ---------------------------------------------------------------------

   function Total_Sentence_Days (Court : Court_Record) return Aggregate_Days
     with
       Global => null,
       Pre    => Court.Length > 0,
       Post   => Total_Sentence_Days'Result <=
                 Aggregate_Days (Court.Length) * Max_Days;

   ---------------------------------------------------------------------
   --  Cross-source agreement — explicit reconciliation step that today
   --  happens implicitly in human cross-checks.
   ---------------------------------------------------------------------

   function Records_Agree
     (Court  : Court_Record;
      NOMIS  : NOMIS_Record;
      OASys  : OASys_Record;
      Delius : Delius_Record) return Boolean
   is
     (Match (Court.Subject, NOMIS.Subject)
      and then Match (Court.Subject, OASys.Subject)
      and then Match (Court.Subject, Delius.Subject))
     with Global => null;

   ---------------------------------------------------------------------
   --  Decision outcome.
   ---------------------------------------------------------------------

   type Decision_Reason is
     (Released,
      Subject_Id_Mismatch,
      No_Sentences,                   --  Court.Length = 0 (new for v2)
      Time_Served_Exceeds_Sentence,
      Discount_Exceeds_Remaining,
      Active_Restriction_Held,
      Recall_Active);

   ---------------------------------------------------------------------
   --  The single decision procedure.
   --
   --  Outputs Days_Until_Release (relative count) and Release_Day
   --  (absolute Day_Number = Court.Start_Day + remaining-from-total).
   --  Both are zero on every non-Released path.
   --
   --  Precondition Court.Start_Day + Max_Sentences * Max_Days <=
   --  Day_Number'Last keeps the addition Release_Day = Start_Day +
   --  remaining within Day_Number. With Day_Number'Last = 1_000_000
   --  and Max_Sentences * Max_Days = 292_000, this gives Start_Day a
   --  permitted range of 0 .. 708_000 — about 1,940 years of headroom.
   ---------------------------------------------------------------------

   procedure Decide
     (Court              : in  Court_Record;
      NOMIS              : in  NOMIS_Record;
      OASys              : in  OASys_Record;
      Delius             : in  Delius_Record;
      Days_Until_Release : out Aggregate_Days;
      Release_Day        : out Day_Number;
      Reason             : out Decision_Reason)
     with
       Global  => null,
       Depends => ((Days_Until_Release, Release_Day, Reason) =>
                     (Court, NOMIS, OASys, Delius)),
       Pre     => Court.Start_Day <= Day_Number'Last - Max_Sentences * Max_Days,
       Post =>
         (case Reason is
            when Released =>
              Court.Length > 0
              and then Records_Agree (Court, NOMIS, OASys, Delius)
              and then NOMIS.Time_Served_Days <= Total_Sentence_Days (Court)
              and then OASys.Behaviour_Discount
                       <= Total_Sentence_Days (Court) - NOMIS.Time_Served_Days
              and then not OASys.Active_Restriction
              and then not Delius.Recall_Active
              and then Days_Until_Release =
                       Total_Sentence_Days (Court) - NOMIS.Time_Served_Days
                       - OASys.Behaviour_Discount
              and then Release_Day = Court.Start_Day + Days_Until_Release,

            when No_Sentences =>
              Court.Length = 0
              and then Days_Until_Release = 0
              and then Release_Day = 0,

            when Subject_Id_Mismatch =>
              Court.Length > 0
              and then not Records_Agree (Court, NOMIS, OASys, Delius)
              and then Days_Until_Release = 0
              and then Release_Day = 0,

            when Time_Served_Exceeds_Sentence =>
              Court.Length > 0
              and then Records_Agree (Court, NOMIS, OASys, Delius)
              and then NOMIS.Time_Served_Days > Total_Sentence_Days (Court)
              and then Days_Until_Release = 0
              and then Release_Day = 0,

            when Discount_Exceeds_Remaining =>
              Court.Length > 0
              and then Records_Agree (Court, NOMIS, OASys, Delius)
              and then NOMIS.Time_Served_Days <= Total_Sentence_Days (Court)
              and then OASys.Behaviour_Discount
                       > Total_Sentence_Days (Court) - NOMIS.Time_Served_Days
              and then Days_Until_Release = 0
              and then Release_Day = 0,

            when Active_Restriction_Held =>
              Court.Length > 0
              and then Records_Agree (Court, NOMIS, OASys, Delius)
              and then NOMIS.Time_Served_Days <= Total_Sentence_Days (Court)
              and then OASys.Behaviour_Discount
                       <= Total_Sentence_Days (Court) - NOMIS.Time_Served_Days
              and then OASys.Active_Restriction
              and then Days_Until_Release = 0
              and then Release_Day = 0,

            when Recall_Active =>
              Court.Length > 0
              and then Records_Agree (Court, NOMIS, OASys, Delius)
              and then NOMIS.Time_Served_Days <= Total_Sentence_Days (Court)
              and then OASys.Behaviour_Discount
                       <= Total_Sentence_Days (Court) - NOMIS.Time_Served_Days
              and then not OASys.Active_Restriction
              and then Delius.Recall_Active
              and then Days_Until_Release = 0
              and then Release_Day = 0);

private

   --  Distinct derived integer subtypes — assignment-incompatible.
   type Court_Subject_Id  is new Natural;
   type NOMIS_Subject_Id  is new Natural;
   type OASys_Subject_Id  is new Natural;
   type Delius_Subject_Id is new Natural;

   function Court_Id  (Raw : Natural) return Court_Subject_Id  is
     (Court_Subject_Id  (Raw));
   function NOMIS_Id  (Raw : Natural) return NOMIS_Subject_Id  is
     (NOMIS_Subject_Id  (Raw));
   function OASys_Id  (Raw : Natural) return OASys_Subject_Id  is
     (OASys_Subject_Id  (Raw));
   function Delius_Id (Raw : Natural) return Delius_Subject_Id is
     (Delius_Subject_Id (Raw));

   function Match (A : Court_Subject_Id; B : NOMIS_Subject_Id) return Boolean is
     (Natural (A) = Natural (B));
   function Match (A : Court_Subject_Id; B : OASys_Subject_Id) return Boolean is
     (Natural (A) = Natural (B));
   function Match (A : Court_Subject_Id; B : Delius_Subject_Id) return Boolean is
     (Natural (A) = Natural (B));

end HMPPS_Release;
