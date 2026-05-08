# Specification — plain-English reading

The Ada/SPARK specification at `src/hmpps_release.ads` reads, almost
sentence-by-sentence, as follows:

> A sentence-release calculation has four input sources: a Court record
> (the original sentence), a NOMIS record (custody time served), an OASys
> record (behavioural discount earned and active restrictions), and a
> Delius record (probation status, including any active recall).
>
> Each source has its own subject identifier — Court_Subject_Id,
> NOMIS_Subject_Id, OASys_Subject_Id, Delius_Subject_Id. These are
> distinct Ada types. The compiler refuses to silently substitute one
> for another. Cross-source agreement is established by the
> Records_Agree function, which calls Match() across all four sources
> and returns true only when all four IDs reference the same subject.
>
> The Decide procedure takes all four records and produces a tuple
> of (Days_Until_Release, Release_Day, Reason). The Reason is one of
> seven named values: Released, No_Sentences, Subject_Id_Mismatch,
> Time_Served_Exceeds_Sentence, Discount_Exceeds_Remaining,
> Active_Restriction_Held, or Recall_Active.
>
> Decide's postcondition specifies, by case, the conditions under
> which each Reason is permitted. A release is issued (Reason =
> Released) only when all four sources agree on subject identity,
> the time served does not exceed the aggregate sentence, the
> behavioural discount does not exceed the remaining sentence, no
> OASys restriction is active, and no Delius recall is active.
> Otherwise Decide produces a non-release reason from the named
> set, with Days_Until_Release and Release_Day set to zero.
>
> The gnatprove tool, given the specification and body, produces a
> machine-checked proof that the body's behaviour stays within the
> postcondition for every input the type system admits. The proof
> is over the contract; it does not extend to the contract's
> correctness against UK sentencing policy.

Read alongside the actual Ada source, the .ads file is the authoritative
contract. This document is a navigational aid only.
