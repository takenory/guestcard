--
-- createuser -U pgsql guestcard
-- createdb -U pgsql guestcard
-- psql -U pgsql guestcard

create table guests (
	id serial,		-- シリアル番号（自動採番）
	created_at timestamp(0)
	  without time zone,	-- 日時
	name text,		-- 代表者氏名
	number integer,		-- 人数
	organization text,	-- 所属
	purpose text,		-- 用件 {制度利用|技術相談|事業等打合せ|その他}
	purpose_option text,	-- 用件（自由入力）
	person text		-- 担当
);

grant select,insert,delete,update on guests to guestcard;
grant select,update on guests_id_seq to guestcard;
