require "formula"

class HunspellForEmacs133 < Formula
  homepage "http://hunspell.sourceforge.net/"
  url "https://downloads.sourceforge.net/hunspell/hunspell-1.3.3.tar.gz"
  sha1 "219b20f305d6690f666ff3864a16e4674908a553"

  depends_on "readline"

  # hunspell does not prepend $HOME to all USEROODIRs
  # http://sourceforge.net/p/hunspell/bugs/236/
  patch :p0, :DATA

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--with-ui",
                          "--with-readline"
    system "make"
    ENV.deparallelize
    system "make install"
  end

  def caveats; <<-EOS.undent
    Dictionary files (*.aff and *.dic) should be placed in
    ~/Library/Spelling/ or /Library/Spelling/.  Homebrew itself
    provides no dictionaries for Hunspell, but you can download
    compatible dictionaries from other sources, such as
    https://wiki.openoffice.org/wiki/Dictionaries .
    EOS
  end
end

__END__
--- src/tools/hunspell.cxx.old	2013-08-02 18:21:49.000000000 +0200
+++ src/tools/hunspell.cxx	2013-08-02 18:20:27.000000000 +0200
@@ -28,7 +28,7 @@
 #ifdef WIN32
 
 #define LIBDIR "C:\\Hunspell\\"
-#define USEROOODIR "Application Data\\OpenOffice.org 2\\user\\wordbook"
+#define USEROOODIR { "Application Data\\OpenOffice.org 2\\user\\wordbook" }
 #define OOODIR \
     "C:\\Program files\\OpenOffice.org 2.4\\share\\dict\\ooo\\;" \
     "C:\\Program files\\OpenOffice.org 2.3\\share\\dict\\ooo\\;" \
@@ -65,11 +65,11 @@
     "/usr/share/myspell:" \
     "/usr/share/myspell/dicts:" \
     "/Library/Spelling"
-#define USEROOODIR \
-    ".openoffice.org/3/user/wordbook:" \
-    ".openoffice.org2/user/wordbook:" \
-    ".openoffice.org2.0/user/wordbook:" \
-    "Library/Spelling"
+#define USEROOODIR { \
+    ".openoffice.org/3/user/wordbook:", \
+    ".openoffice.org2/user/wordbook:", \
+    ".openoffice.org2.0/user/wordbook:", \
+    "Library/Spelling" }
 #define OOODIR \
     "/opt/openoffice.org/basis3.0/share/dict/ooo:" \
     "/usr/lib/openoffice.org/basis3.0/share/dict/ooo:" \
@@ -1664,7 +1664,10 @@
 	path = add(path, PATHSEP);          // <- check path in root directory
 	if (getenv("DICPATH")) path = add(add(path, getenv("DICPATH")), PATHSEP);
 	path = add(add(path, LIBDIR), PATHSEP);
-	if (HOME) path = add(add(add(add(path, HOME), DIRSEP), USEROOODIR), PATHSEP);
+  const char* userooodir[] = USEROOODIR;
+  for (int i = 0; i < (sizeof(userooodir) / sizeof(userooodir[0])); i++) {
+    if (HOME) path = add(add(add(add(path, HOME), DIRSEP), userooodir[i]), PATHSEP);
+  }
 	path = add(path, OOODIR);
 
 	if (showpath) {

# --- src/parsers/textparser.cxx
# +++ src/parsers/textparser.cxx
# @@ -96,7 +96,9 @@ void TextParser::init(const char * wordchars)
#  	}
#  	actual = 0;
#  	head = 0;
# +	head_char = 0;
#  	token = 0;
# +	token_char = 0;
#  	state = 0;
#          utf8 = 0;
#          checkurl = 0;
# @@ -117,7 +119,9 @@ void TextParser::init(unsigned short * wc, int len)
#  	}
#  	actual = 0;
#  	head = 0;
# +	head_char = 0;
#  	token = 0;
# +	token_char = 0;
#  	state = 0;
#  	utf8 = 1;
#  	checkurl = 0;
# @@ -143,7 +147,9 @@ void TextParser::put_line(char * word)
#  	actual = (actual + 1) % MAXPREVLINE;
#  	strcpy(line[actual], word);
#  	token = 0;
# +	token_char = 0;
#  	head = 0;
# +	head_char = 0;
#  	check_urls();
#  }
 
# @@ -168,15 +174,21 @@ char * TextParser::next_token()
#  			if (is_wordchar(line[actual] + head)) {
#  				state = 1;
#  				token = head;
# +				token_char = head_char;
#  			} else if ((latin1 = get_latin1(line[actual] + head))) {
#  				state = 1;
#  				token = head;
# -				head += strlen(latin1);
# +				token_char = head_char;
# +				int latin1_len = strlen(latin1);
# +				head += latin1_len;
# +				head_char += latin1_len;
#  			}
#  			break;
#  		case 1: // wordchar
#  			if ((latin1 = get_latin1(line[actual] + head))) {
# -				head += strlen(latin1);
# +				int latin1_len = strlen(latin1);
# +				head += latin1_len;
# +				head_char += latin1_len;
#  			} else if (! is_wordchar(line[actual] + head)) {
#  				state = 0;
#  				char * t = alloc_token(token, &head);
# @@ -184,7 +196,9 @@ char * TextParser::next_token()
#  			}
#  			break;
#  		}
# -                if (next_char(line[actual], &head)) return NULL;
# +		int nc_result = next_char(line[actual], &head);
# +		head_char++;
# +                if (nc_result) return NULL;
#  	}
#  }
 
# @@ -193,6 +207,12 @@ int TextParser::get_tokenpos()
#  	return token;
#  }
 
# +int TextParser::get_token_charpos()
# +{
# +	return token_char;
# +}
# +
# +
#  int TextParser::change_token(const char * word)
#  {
#  	if (word) {
# @@ -200,6 +220,7 @@ int TextParser::change_token(const char * word)
#  		strcpy(line[actual] + token, word);
#  		strcat(line[actual], r);
#  		head = token;
# +		head_char = token_char;
#  		free(r);
#  		return 1;
#  	}

# --- src/parsers/textparser.hxx
# +++ src/parsers/textparser.hxx
# @@ -41,6 +41,10 @@ protected:
#    unsigned short *    wordchars_utf16;
#    int                 wclen;
 
# +  // for tracking UTF-8 character positions
# +  int                 head_char;
# +  int                 token_char;
# +    
#  public:
  
#    TextParser();
# @@ -56,6 +60,8 @@ public:
#    void                set_url_checking(int check);
 
#    int                 get_tokenpos();
# +  int                 get_token_charpos();  
# +    
#    int                 is_wordchar(char * w);
#    const char *        get_latin1(char * s);
#    char *              next_char();


--- src/tools/hunspell.cxx
+++ src/tools/hunspell.cxx
@@ -710,13 +748,22 @@ if (pos >= 0) {
 			fflush(stdout);
 		} else {
 			char ** wlst = NULL;
-			int ns = pMS[d]->suggest(&wlst, token);
+			int byte_offset = parser->get_tokenpos() + pos;
+			int char_offset = 0;
+			if (strcmp(io_enc, "UTF-8") == 0) {
+				for (int i = 0; i < byte_offset; i++) {
+					if ((buf[i] & 0xc0) != 0x80)
+						char_offset++;
+				}
+			} else {
+				char_offset = byte_offset;
+			}
+			int ns = pMS[d]->suggest(&wlst, chenc(token, io_enc, dic_enc[d]));
 			if (ns == 0) {
-		    		fprintf(stdout,"# %s %d", token,
-		    		    parser->get_tokenpos() + pos);
+		    		fprintf(stdout,"# %s %d", token, char_offset);
 			} else {
 				fprintf(stdout,"& %s %d %d: ", token, ns,
-				    parser->get_tokenpos() + pos);
+					char_offset);
 				fprintf(stdout,"%s", chenc(wlst[0], dic_enc[d], io_enc));
 			}
 			for (int j = 1; j < ns; j++) {
@@ -745,13 +792,23 @@ if (pos >= 0) {
 			if (root) free(root);
 		} else {
 			char ** wlst = NULL;
+			int byte_offset = parser->get_tokenpos() + pos;
+			int char_offset = 0;
+			if (strcmp(io_enc, "UTF-8") == 0) {
+				for (int i = 0; i < byte_offset; i++) {
+					if ((buf[i] & 0xc0) != 0x80)
+						char_offset++;
+				}
+			} else {
+				char_offset = byte_offset;
+			}
 			int ns = pMS[d]->suggest(&wlst, chenc(token, io_enc, dic_enc[d]));
 			if (ns == 0) {
 		    		fprintf(stdout,"# %s %d", chenc(token, io_enc, ui_enc),
-		    		    parser->get_tokenpos() + pos);
+		    		    char_offset);
 			} else {
 				fprintf(stdout,"& %s %d %d: ", chenc(token, io_enc, ui_enc), ns,
-				    parser->get_tokenpos() + pos);
+				    char_offset);
 				fprintf(stdout,"%s", chenc(wlst[0], dic_enc[d], ui_enc));
 			}
 			for (int j = 1; j < ns; j++) {
