--  hmpps_release_gui.adb
--  ===========================================================================
--  Gnoga front-end for the HMPPS sentence-release calculator.
--
--  Single-stack Ada: the SPARK-verified core (HMPPS_Release.Decide) is
--  called directly from the GUI handler. No FFI, no JSON, no IPC.

with Ada.Exceptions;
with Ada.Calendar;
with Ada.Calendar.Arithmetic;
with Ada.Calendar.Formatting;

with UXStrings;

with Gnoga;
with Gnoga.Application.Multi_Connect;
with Gnoga.Gui.Base;
with Gnoga.Gui.Element.Common;
with Gnoga.Gui.Element.Form;
with Gnoga.Types;
with Gnoga.Gui.View;
with Gnoga.Gui.Window;

with HMPPS_Release;

procedure HMPPS_Release_Gui is
   use Gnoga;
   use all type Gnoga.String;

   Disclaimer_Banner : constant Gnoga.String :=
     "DEMONSTRATOR ONLY. This calculator has no real domain model "
     & "(no parole rules, no HDC/ROTL, no live data feeds). It demonstrates "
     & "a type-discipline structural fix; it is NOT for use in real release "
     & "decisions.";

   --------------------------------------------------------------------
   --  Calendar helpers — GUI-layer only (NOT in the SPARK core).
   --
   --  Epoch is 1970-01-01. The SPARK core works in integer Day_Number;
   --  the GUI converts to/from ISO calendar dates at the I/O boundary.
   --------------------------------------------------------------------

   function Days_Since_Epoch (Date_Str : Standard.String) return Integer is
      use Ada.Calendar;
      use Ada.Calendar.Arithmetic;

      Epoch : constant Time := Time_Of (1970, 1, 1);
      T     : constant Time := Time_Of
        (Year   => Year_Number   (Integer'Value (Date_Str (Date_Str'First     .. Date_Str'First + 3))),
         Month  => Month_Number  (Integer'Value (Date_Str (Date_Str'First + 5 .. Date_Str'First + 6))),
         Day    => Day_Number    (Integer'Value (Date_Str (Date_Str'First + 8 .. Date_Str'First + 9))));
      Days  : Day_Count;
      Secs  : Duration;
      Lps   : Leap_Seconds_Count;
   begin
      Difference (T, Epoch, Days, Secs, Lps);
      return Integer (Days);
   end Days_Since_Epoch;

   function Day_Num_To_Date_String (D : Integer) return Standard.String is
      use Ada.Calendar;
      use Ada.Calendar.Arithmetic;

      Epoch : constant Time := Time_Of (1970, 1, 1);
      T     : constant Time := Epoch + Day_Count (D);
      Img   : constant Standard.String := Ada.Calendar.Formatting.Image (T);
   begin
      --  Image returns "YYYY-MM-DD HH:MM:SS"; take the date prefix.
      return Img (Img'First .. Img'First + 9);
   end Day_Num_To_Date_String;

   --------------------------------------------------------------------
   --  Per-connection state.
   --------------------------------------------------------------------

   type App_Info is new Gnoga.Types.Connection_Data_Type with record
      Window     : Gnoga.Gui.Window.Pointer_To_Window_Class;
      View       : Gnoga.Gui.View.View_Type;

      Banner     : Gnoga.Gui.Element.Common.DIV_Type;
      Title      : Gnoga.Gui.Element.Common.DIV_Type;

      Form       : Gnoga.Gui.Element.Form.Form_Type;

      Court_Sub_L  : Gnoga.Gui.Element.Form.Label_Type;
      Court_Sub    : Gnoga.Gui.Element.Form.Number_Type;
      NOMIS_Sub_L  : Gnoga.Gui.Element.Form.Label_Type;
      NOMIS_Sub    : Gnoga.Gui.Element.Form.Number_Type;
      OASys_Sub_L  : Gnoga.Gui.Element.Form.Label_Type;
      OASys_Sub    : Gnoga.Gui.Element.Form.Number_Type;
      Delius_Sub_L : Gnoga.Gui.Element.Form.Label_Type;
      Delius_Sub   : Gnoga.Gui.Element.Form.Number_Type;

      Start_Date_L : Gnoga.Gui.Element.Form.Label_Type;
      Start_Date   : Gnoga.Gui.Element.Form.Date_Type;
      Sentence_L   : Gnoga.Gui.Element.Form.Label_Type;
      Sentence     : Gnoga.Gui.Element.Form.Number_Type;

      Time_Served_L : Gnoga.Gui.Element.Form.Label_Type;
      Time_Served   : Gnoga.Gui.Element.Form.Number_Type;
      Discount_L    : Gnoga.Gui.Element.Form.Label_Type;
      Discount      : Gnoga.Gui.Element.Form.Number_Type;
      Restriction_L : Gnoga.Gui.Element.Form.Label_Type;
      Restriction   : Gnoga.Gui.Element.Form.Check_Box_Type;
      Recall_L      : Gnoga.Gui.Element.Form.Label_Type;
      Recall        : Gnoga.Gui.Element.Form.Check_Box_Type;

      Result_Reason : Gnoga.Gui.Element.Common.DIV_Type;
      Result_Days   : Gnoga.Gui.Element.Common.DIV_Type;
      Result_Day    : Gnoga.Gui.Element.Common.DIV_Type;

      Footer        : Gnoga.Gui.Element.Common.DIV_Type;

      Calculate     : Gnoga.Gui.Element.Form.Submit_Button_Type;
   end record;

   type App_Ptr is access all App_Info;

   --------------------------------------------------------------------
   --  Calculate handler — calls into the SPARK core.
   --------------------------------------------------------------------

   procedure On_Calculate (Object : in out Gnoga.Gui.Base.Base_Type'Class) is
      App : constant App_Ptr := App_Ptr (Object.Connection_Data);

      use HMPPS_Release;

      Court  : Court_Record;
      NOMIS  : NOMIS_Record;
      OASys  : OASys_Record;
      Delius : Delius_Record;

      Days   : Aggregate_Days;
      RDay   : Day_Number;
      Reason : Decision_Reason;

      Empty  : constant Sentence_Record := (Kind => Consecutive, Duration => 0);
      Sents  : Sentence_Array := (others => Empty);

      Court_Sub_I  : constant Integer := Value (App.Court_Sub.Value);
      NOMIS_Sub_I  : constant Integer := Value (App.NOMIS_Sub.Value);
      OASys_Sub_I  : constant Integer := Value (App.OASys_Sub.Value);
      Delius_Sub_I : constant Integer := Value (App.Delius_Sub.Value);
      Start_I      : constant Integer :=
        Days_Since_Epoch (UXStrings.To_UTF_8 (App.Start_Date.Value));
      Dur_I        : constant Integer := Value (App.Sentence.Value);
      Served_I     : constant Integer := Value (App.Time_Served.Value);
      Disc_I       : constant Integer := Value (App.Discount.Value);
   begin
      Sents (1) := (Kind => Consecutive, Duration => Day_Count (Dur_I));
      Court     := (Subject   => Court_Id (Natural (Court_Sub_I)),
                    Start_Day => Day_Number (Start_I),
                    Sentences => Sents,
                    Length    => 1);

      NOMIS := (Subject          => NOMIS_Id (Natural (NOMIS_Sub_I)),
                Time_Served_Days => Aggregate_Days (Served_I));

      OASys := (Subject            => OASys_Id (Natural (OASys_Sub_I)),
                Behaviour_Discount => Aggregate_Days (Disc_I),
                Active_Restriction => App.Restriction.Checked);

      Delius := (Subject       => Delius_Id (Natural (Delius_Sub_I)),
                 Recall_Active => App.Recall.Checked);

      --  CALL INTO THE SPARK CORE.
      Decide (Court, NOMIS, OASys, Delius, Days, RDay, Reason);

      App.Result_Reason.Inner_HTML
        ("<strong>" & From_UTF_8 (Decision_Reason'Image (Reason)) & "</strong>");

      if Reason = Released then
         App.Result_Days.Inner_HTML
           ("Days until release: <strong>" & Image (Integer (Days)) & "</strong>");
         App.Result_Day.Inner_HTML
           ("Release date: <strong>"
            & From_UTF_8 (Day_Num_To_Date_String (Integer (RDay)))
            & "</strong>");
      else
         App.Result_Days.Inner_HTML ("(no release date issued)");
         App.Result_Day.Inner_HTML  ("");
      end if;
   exception
      when E : others =>
         App.Result_Reason.Inner_HTML
           ("ERROR: " & From_UTF_8 (Ada.Exceptions.Exception_Message (E)));
         App.Result_Days.Inner_HTML ("");
         App.Result_Day.Inner_HTML  ("");
   end On_Calculate;

   --------------------------------------------------------------------
   --  Connection setup — input first, label second (label's auto-place
   --  references the input it labels, which must already exist).
   --------------------------------------------------------------------

   procedure On_Connect
     (Main_Window : in out Gnoga.Gui.Window.Window_Type'Class;
      Connection  :    access Gnoga.Application.Multi_Connect.Connection_Holder_Type)
   is
      pragma Unreferenced (Connection);

      App : constant App_Ptr := new App_Info;
   begin
      Main_Window.Connection_Data (Data => App);
      App.Window := Main_Window'Unchecked_Access;

      App.View.Create   (Parent => Main_Window);
      App.View.Box_Width (Value => 760);

      App.Banner.Create  (Parent => App.View, Content => Disclaimer_Banner);
      App.Banner.Background_Color ("#fff3cd");
      App.Banner.Color  ("#664d03");

      App.Title.Create (Parent => App.View,
                        Content =>
                          "<h2>HMPPS sentence-release calculator</h2>"
                          & "<p>Formally-verified Ada/SPARK 2014 demonstrator. "
                          & "<a href=""https://github.com/tonygair/hmpps-release-calculator"" target=""_blank"">"
                          & "Source &amp; proof on GitHub.</a></p>");

      App.Form.Create (Parent => App.View);

      --  For each row: input first, label second (with Label_For pointing
      --  back at the input). This is the order Gnoga's auto-place needs.

      App.Court_Sub.Create (Form => App.Form);
      App.Court_Sub.Value (12345);
      App.Court_Sub_L.Create (Form => App.Form, Label_For => App.Court_Sub,
                              Content => "Court subject ID: ");
      App.Form.New_Line;

      App.NOMIS_Sub.Create (Form => App.Form);
      App.NOMIS_Sub.Value (12345);
      App.NOMIS_Sub_L.Create (Form => App.Form, Label_For => App.NOMIS_Sub,
                              Content => "NOMIS subject ID: ");
      App.Form.New_Line;

      App.OASys_Sub.Create (Form => App.Form);
      App.OASys_Sub.Value (12345);
      App.OASys_Sub_L.Create (Form => App.Form, Label_For => App.OASys_Sub,
                              Content => "OASys subject ID: ");
      App.Form.New_Line;

      App.Delius_Sub.Create (Form => App.Form);
      App.Delius_Sub.Value (12345);
      App.Delius_Sub_L.Create (Form => App.Form, Label_For => App.Delius_Sub,
                               Content => "Delius subject ID: ");
      App.Form.New_Line;

      App.Start_Date.Create (Form => App.Form);
      App.Start_Date.Value ("2024-06-01");  --  arbitrary recent date for the demo
      App.Start_Date_L.Create (Form => App.Form, Label_For => App.Start_Date,
                               Content => "Sentence start date: ");
      App.Form.New_Line;

      App.Sentence.Create (Form => App.Form);
      App.Sentence.Value (1000);
      App.Sentence_L.Create (Form => App.Form, Label_For => App.Sentence,
                             Content => "Sentence duration (days): ");
      App.Form.New_Line;

      App.Time_Served.Create (Form => App.Form);
      App.Time_Served.Value (600);
      App.Time_Served_L.Create (Form => App.Form, Label_For => App.Time_Served,
                                Content => "NOMIS time served (days): ");
      App.Form.New_Line;

      App.Discount.Create (Form => App.Form);
      App.Discount.Value (100);
      App.Discount_L.Create (Form => App.Form, Label_For => App.Discount,
                             Content => "OASys behaviour discount (days): ");
      App.Form.New_Line;

      App.Restriction.Create (Form => App.Form);
      App.Restriction_L.Create (Form => App.Form, Label_For => App.Restriction,
                                Content => "OASys active restriction");
      App.Form.New_Line;

      App.Recall.Create (Form => App.Form);
      App.Recall_L.Create (Form => App.Form, Label_For => App.Recall,
                           Content => "Delius recall active");
      App.Form.New_Line;
      App.Form.New_Line;

      App.Calculate.Create (Form => App.Form, Value => "Calculate");
      App.Form.On_Submit_Handler (Handler => On_Calculate'Unrestricted_Access);
      App.Form.New_Line;
      App.Form.New_Line;

      App.Result_Reason.Create (Parent => App.View, Content => "(awaiting input)");
      App.Result_Days.Create   (Parent => App.View, Content => "");
      App.Result_Day.Create    (Parent => App.View, Content => "");

      App.Footer.Create
        (Parent  => App.View,
         Content =>
           "<hr style=""margin-top:2em""/>"
           & "<p><small><em>Worked demonstrator by "
           & "<strong>The Dark Factory Ltd</strong>, Sunderland. "
           & "To commission a production version, or apply the same "
           & "formally-verified approach to other civilian government "
           & "calculators, contact "
           & "<a href=""mailto:tony.gair@thedarkfactory.co.uk"">"
           & "tony.gair@thedarkfactory.co.uk</a>.</em></small></p>");
   exception
      when E : others =>
         Gnoga.Log (Message => "On_Connect: ", Occurrence => E);
   end On_Connect;

begin
   Gnoga.Application.Title (Name =>
     "HMPPS Sentence Release Calculator — Demonstrator");
   Gnoga.Application.HTML_On_Close
     (HTML => "Demonstrator closed.");
   Gnoga.Application.Multi_Connect.Initialize (Port => 8088);
   Gnoga.Application.Multi_Connect.On_Connect_Handler
     (Event => On_Connect'Unrestricted_Access);
   Gnoga.Application.Multi_Connect.Message_Loop;
exception
   when E : others =>
      Gnoga.Log (E);
end HMPPS_Release_Gui;
