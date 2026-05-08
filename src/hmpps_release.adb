package body HMPPS_Release
  with SPARK_Mode => On
is

   function Total_Sentence_Days (Court : Court_Record) return Aggregate_Days is
      Acc : Aggregate_Days := 0;
   begin
      for I in 1 .. Court.Length loop
         pragma Loop_Invariant
           (Acc <= Aggregate_Days (I - 1) * Max_Days);
         if Court.Sentences (I).Kind = Concurrent then
            Acc := Aggregate_Days'Max (Acc, Court.Sentences (I).Duration);
         else
            Acc := Acc + Court.Sentences (I).Duration;
         end if;
      end loop;
      return Acc;
   end Total_Sentence_Days;

   procedure Decide
     (Court              : in  Court_Record;
      NOMIS              : in  NOMIS_Record;
      OASys              : in  OASys_Record;
      Delius             : in  Delius_Record;
      Days_Until_Release : out Aggregate_Days;
      Release_Day        : out Day_Number;
      Reason             : out Decision_Reason)
   is
      Total_Days : Aggregate_Days;
   begin
      if Court.Length = 0 then
         Reason             := No_Sentences;
         Days_Until_Release := 0;
         Release_Day        := 0;
      elsif not Records_Agree (Court, NOMIS, OASys, Delius) then
         Reason             := Subject_Id_Mismatch;
         Days_Until_Release := 0;
         Release_Day        := 0;
      else
         Total_Days := Total_Sentence_Days (Court);

         if NOMIS.Time_Served_Days > Total_Days then
            Reason             := Time_Served_Exceeds_Sentence;
            Days_Until_Release := 0;
            Release_Day        := 0;
         elsif OASys.Behaviour_Discount > Total_Days - NOMIS.Time_Served_Days then
            Reason             := Discount_Exceeds_Remaining;
            Days_Until_Release := 0;
            Release_Day        := 0;
         elsif OASys.Active_Restriction then
            Reason             := Active_Restriction_Held;
            Days_Until_Release := 0;
            Release_Day        := 0;
         elsif Delius.Recall_Active then
            Reason             := Recall_Active;
            Days_Until_Release := 0;
            Release_Day        := 0;
         else
            Reason             := Released;
            Days_Until_Release := Total_Days - NOMIS.Time_Served_Days
                                    - OASys.Behaviour_Discount;
            Release_Day        := Court.Start_Day + Days_Until_Release;
         end if;
      end if;
   end Decide;

end HMPPS_Release;
