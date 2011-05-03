/* DO NOT MODIFY. This file was compiled Mon, 02 May 2011 11:07:37 GMT from
 * /Users/jsmith/dev/RapidFTR/dev/app/coffeescripts/models/media/player.coffee
 */

(function() {
  var namespace, _ref;
  namespace = typeof exports != "undefined" && exports !== null ? exports : this;
  namespace = (_ref = namespace.Media) != null ? _ref : namespace.Media = {};
  namespace.Player = (function() {
    function Player() {
      this.isPlaying = false;
    }
    Player.prototype.play = function(currentlyPlayingSong) {
      this.currentlyPlayingSong = currentlyPlayingSong;
      return this.isPlaying = true;
    };
    Player.prototype.pause = function() {
      return this.isPlaying = false;
    };
    Player.prototype.resume = function() {
      if (this.isPlaying) {
        throw new Error("song is already playing");
      }
      return this.isPlaying = true;
    };
    Player.prototype.makeFavorite = function() {
      return this.currentlyPlayingSong.persistFavoriteStatus(true);
    };
    return Player;
  })();
}).call(this);
