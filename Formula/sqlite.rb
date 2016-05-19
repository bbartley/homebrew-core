class Sqlite < Formula
  desc "Command-line interface for SQLite"
  homepage "https://sqlite.org/"
  url "https://sqlite.org/2016/sqlite-autoconf-3130000.tar.gz"
  version "3.13.0"
  sha256 "e2797026b3310c9d08bd472f6d430058c6dd139ff9d4e30289884ccd9744086b"

  bottle do
    cellar :any
    sha256 "3df8f74f3b6f60a84bb448a817fd0e57a72d31d551b96bb4eda55b3777824435" => :el_capitan
    sha256 "f87798b68786217d1580371167e9951433ca646485f0dacb4b0dba28d36a6696" => :yosemite
    sha256 "3685bc0ad0ff7de50a0f927a96afc067d7386cfa617c0a02ef9f78340262dab5" => :mavericks
  end

  keg_only :provided_by_osx, "OS X provides an older sqlite3."

  option :universal
  option "with-docs", "Install HTML documentation"
  option "without-rtree", "Disable the R*Tree index module"
  option "with-fts", "Enable the FTS3 module"
  option "with-fts5", "Enable the FTS5 module (experimental)"
  option "with-secure-delete", "Defaults secure_delete to on"
  option "with-unlock-notify", "Enable the unlock notification feature"
  option "with-icu4c", "Enable the ICU module"
  option "with-functions", "Enable more math and string functions for SQL queries"
  option "with-dbstat", "Enable the 'dbstat' virtual table"
  option "with-json1", "Enable the JSON1 extension"

  depends_on "readline" => :recommended
  depends_on "icu4c" => :optional

  resource "functions" do
    url "https://sqlite.org/contrib/download/extension-functions.c?get=25", :using => :nounzip
    version "2010-01-06"
    sha256 "991b40fe8b2799edc215f7260b890f14a833512c9d9896aa080891330ffe4052"
  end

  resource "docs" do
    url "https://sqlite.org/2016/sqlite-doc-3130000.zip"
    version "3.13.0"
    sha256 "510606a9cdd89814b2d44e7b7f284ebb0a58153e1800de6daadfab445190f79c"
  end

  def install
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_COLUMN_METADATA=1"
    # Default value of MAX_VARIABLE_NUMBER is 999 which is too low for many
    # applications. Set to 250000 (Same value used in Debian and Ubuntu).
    ENV.append "CPPFLAGS", "-DSQLITE_MAX_VARIABLE_NUMBER=250000"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_RTREE=1" if build.with? "rtree"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" if build.with? "fts"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_FTS5=1" if build.with? "fts5"
    ENV.append "CPPFLAGS", "-DSQLITE_SECURE_DELETE=1" if build.with? "secure-delete"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_UNLOCK_NOTIFY=1" if build.with? "unlock-notify"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_DBSTAT_VTAB=1" if build.with? "dbstat"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_JSON1=1" if build.with? "json1"

    if build.with? "icu4c"
      icu4c = Formula["icu4c"]
      icu4cldflags = `#{icu4c.opt_bin}/icu-config --ldflags`.tr("\n", " ")
      icu4ccppflags = `#{icu4c.opt_bin}/icu-config --cppflags`.tr("\n", " ")
      ENV.append "LDFLAGS", icu4cldflags
      ENV.append "CPPFLAGS", icu4ccppflags
      ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_ICU=1"
    end

    ENV.universal_binary if build.universal?

    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "--enable-dynamic-extensions"
    system "make", "install"

    if build.with? "functions"
      buildpath.install resource("functions")
      system ENV.cc, "-fno-common",
                     "-dynamiclib",
                     "extension-functions.c",
                     "-o", "libsqlitefunctions.dylib",
                     *ENV.cflags.to_s.split
      lib.install "libsqlitefunctions.dylib"
    end
    doc.install resource("docs") if build.with? "docs"
  end

  def caveats
    if build.with? "functions" then <<-EOS.undent
      Usage instructions for applications calling the sqlite3 API functions:

        In your application, call sqlite3_enable_load_extension(db,1) to
        allow loading external libraries.  Then load the library libsqlitefunctions
        using sqlite3_load_extension; the third argument should be 0.
        See https://sqlite.org/loadext.html.
        Select statements may now use these functions, as in
        SELECT cos(radians(inclination)) FROM satsum WHERE satnum = 25544;

      Usage instructions for the sqlite3 program:

        If the program is built so that loading extensions is permitted,
        the following will work:
         sqlite> SELECT load_extension('#{lib}/libsqlitefunctions.dylib');
         sqlite> select cos(radians(45));
         0.707106781186548
      EOS
    end
  end

  test do
    path = testpath/"school.sql"
    path.write <<-EOS.undent
      create table students (name text, age integer);
      insert into students (name, age) values ('Bob', 14);
      insert into students (name, age) values ('Sue', 12);
      insert into students (name, age) values ('Tim', 13);
      select name from students order by age asc;
    EOS

    names = shell_output("#{bin}/sqlite3 < #{path}").strip.split("\n")
    assert_equal %w[Sue Tim Bob], names
  end
end
