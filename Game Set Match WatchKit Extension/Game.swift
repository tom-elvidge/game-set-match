//
//  Game.swift
//  Game Set Match WatchKit Extension
//
//  Created by Tom Elvidge on 18/07/2021.
//

import Foundation

class Game: ObservableObject {
    
    // Game preferences
    private let setsToWin: Int
    private let gamesForSet: Int
    private let firstServe: Bool
    
    // Keep track of the game state history
    private var stateHistory: [TennisState]
    
    // "" if game in progress
    @Published var winner: String
    
    // Display the score board
    @Published var scoreBoard: ScoreBoard
    
    init (setsToWin: Int, gamesForSet: Int, firstServe: Bool) {
        // Set game preferences
        self.setsToWin = setsToWin
        self.gamesForSet = gamesForSet
        self.firstServe = firstServe
        
        // Create initial TennisState and history
        self.stateHistory = []
        self.stateHistory.append(TennisState(toServe: firstServe))
        
        // Create score board from the current state
        // Use bang as the state history will always have the initial state
        self.scoreBoard = self.stateHistory.last!.exportScoreBoard()
        
        // winner = "" when game in progress
        self.winner = ""
    }
    
    func undoLastEvent() {
        // Do not allow removal of the initial state
        if (self.stateHistory.count > 1) {
            self.stateHistory.removeLast()
            
            // Update the score board
            self.scoreBoard = self.stateHistory.last!.exportScoreBoard()
        }
    }
    
    func newEvent(event: TennisEventType) {
        // Get current state from end of history
        // Use bang as there will alsways be at least the initial state
        let currentState = self.stateHistory.last!
        
        // Create new state from current state
        let newState = currentState.copy()
        newState.generationEventType = event
        newState.generationEventTimestamp = NSDate().timeIntervalSince1970
        
        // Update newState using currentState and event
        
        // Different scoring when in a tie break
        if currentState.setTieBreak {
            newState.tieBreakPointCounter += 1
            
            // Switch serve after first point and then after every other point (i.e. odd points)
            if (newState.tieBreakPointCounter % 2 != 0) {
                newState.toServe = !newState.toServe
            }

            if (event == TennisEventType.win) {
                newState.pointsUser += 1
            }
            
            if (event == TennisEventType.loss) {
                newState.pointsOpponent += 1
            }
        } else {
            // No tie break so score normally
            if (event == TennisEventType.win) {
                // If opponent was on advantage put it back to duece
                if (currentState.pointsOpponent == 4) {
                    newState.pointsOpponent -= 1
                } else {
                    // Otherwise just increment points
                    newState.pointsUser += 1
                }
            }
            if (event == TennisEventType.loss) {
                // If user was on advantage put it back to duece
                if (currentState.pointsUser == 4) {
                    newState.pointsUser -= 1
                } else {

                    // Otherwise just increment points
                    newState.pointsOpponent += 1
                }
            }
        }
        
        // Resolve game
        let gamePointTo: PlayerType = currentState.getGamePointTo()
        // Game win
        if (gamePointTo == PlayerType.user && event == TennisEventType.win) {
            newState.gamesUser += 1
            newState.gameReset()
            
        }
        // Game loss
        if (gamePointTo == PlayerType.opponent && event == TennisEventType.loss) {
            newState.gamesOpponent += 1
            newState.gameReset()
        }
        
        // Resolve set
        let setPointTo: PlayerType = currentState.getSetPointTo(gamesForSet: self.gamesForSet)
        // Set win
        if (setPointTo == PlayerType.user && event == TennisEventType.win) {
            newState.setsUser += 1
            newState.setReset()
        }
        // Set loss
        if (setPointTo == PlayerType.opponent && event == TennisEventType.loss) {
            newState.setsOpponent += 1
            newState.setReset()
        }
        
        // Resolve match
        let matchPointTo: PlayerType = currentState.getMatchPointTo(gamesForSet: self.gamesForSet, setsToWin: self.setsToWin)
        // Match win!
        if (matchPointTo == PlayerType.user && event == TennisEventType.win) {
            self.winner = "user"
        }
        // Match loss...
        if (matchPointTo == PlayerType.opponent && event == TennisEventType.loss) {
            self.winner = "opponent"
        }
        
        // If state now in a tie break then keep track of who will serve after
        if newState.isTieBreak(gamesForSet: self.gamesForSet) {
            newState.setTieBreak = true
            newState.toServePostTieBreak = newState.toServe
        }
        
        // Add the fully updated new state to history
        self.stateHistory.append(newState)
        
        // Update the score board
        self.scoreBoard = newState.exportScoreBoard()
    }
    
//    func updateScore(pointWon: Bool) {
//        // Do not update if there is a winner
//        if (winner != "") {
//            return
//        }
//
//        var gameOver = false
//        var setOver = false
//
//        // Score points
//        if setTieBreak {
//            tieBreakPointCounter += 1
//            // Switch serve after first point and then after every other point (i.e. odd points)
//            if (tieBreakPointCounter % 2 != 0) {
//                self.toServe = !self.toServe
//            }
//
//            // Score differently when in a tie break
//            if pointWon {
//                self.pointsUser += 1
//            } else {
//                self.pointsOpponent += 1
//            }
//        } else {
//            // Otherwise, score points normally
//            if pointWon {
//                // If opponent was on advantage put it back to duece
//                if (pointsOpponent == 4) {
//                    self.pointsOpponent -= 1
//                } else {
//                    // Otherwise just increment points
//                    self.pointsUser += 1
//                }
//            } else {
//                // If user was on advantage put it back to duece
//                if (pointsUser == 4) {
//                    self.pointsUser -= 1
//                } else {
//                    // Otherwise just increment points
//                    self.pointsOpponent += 1
//                }
//            }
//        }
//
//        // Check if the game is won
//        if setTieBreak {
//            // Check if the game is won by user
//            // First to 7 points
//            // If 6-6 then first to win two in a row
//            if (self.pointsUser >= 7 && self.pointsUser >= (self.pointsOpponent + 2)) {
//                // Add a game to the user
//                self.gamesUser += 1
//                // Set flag to clean up game score
//                gameOver = true
//                // End tie break
//                self.setTieBreak = false
//                self.tieBreakPointCounter = 0
//                self.toServe = self.toServePostTieBreak
//            }
//
//            // Todo: Tidy repeated code for each player
//            // Check if game is won by opponent
//            if (self.pointsOpponent >= 7 && self.pointsOpponent >= (self.pointsUser + 2)) {
//                // Add a set to the opponent
//                self.gamesOpponent += 1
//                // Set flag to clean up game score
//                gameOver = true
//                // End tie break
//                self.setTieBreak = false
//                self.tieBreakPointCounter = 0
//                self.toServe = self.toServePostTieBreak
//            }
//        } else {
//            // Check if the game is won by user
//            if ((self.pointsUser == 4 && self.pointsOpponent < 3) || self.pointsUser == 5) {
//                // Add a game to the user
//                self.gamesUser += 1
//                // Set flag to clean up game score
//                gameOver = true
//            }
//
//            // Todo: Tidy repeated code for each player
//            // Check if game is won by opponent
//            if ((self.pointsOpponent == 4 && self.pointsUser < 3) || self.pointsOpponent == 5) {
//                // Add a game to the opponent
//                self.gamesOpponent += 1
//                // Set flag to clean up game score
//                gameOver = true
//            }
//        }
//
//        if gameOver {
//            // Reset score of game
//            self.pointsUser = 0
//            self.pointsOpponent = 0
//
//            // Swap service
//            self.toServe = !self.toServe
//
//            // Check if set is won by user
//            // Win the number of games for the set and at least 2 more than the opponent
//            if ((self.gamesUser == self.gamesForSet && self.gamesUser >= (self.gamesOpponent + 2))
//                    // Win by tie break when one more than the games for set
//                    || self.gamesUser == self.gamesForSet + 1) {
//                // Add set to user
//                self.setsUser += 1
//                // Set flag to clean up set score
//                setOver = true
//            }
//
//            // Todo: Tidy repeated code for each player
//            // Check if set is won by opponent
//            if ((self.gamesOpponent == self.gamesForSet && self.gamesOpponent >= (self.gamesUser + 2))
//                    || self.gamesOpponent == self.gamesForSet + 1) {
//                // Add set to opponent
//                self.setsOpponent += 1
//                // Set flag to clean up set score
//                setOver = true
//            }
//
//            // Check if this set is in a tie break
//            if (self.gamesUser  == self.gamesForSet && self.gamesOpponent == self.gamesForSet) {
//                // Set setTieBreak flag for alternate scoring
//                setTieBreak = true
//                // Keep track of who will serve in first game of next set
//                toServePostTieBreak = toServe
//            }
//        }
//
//        if setOver {
//            // Reset score of set
//            self.gamesUser = 0
//            self.gamesOpponent = 0
//
//            // Check if match is won by user
//            if (self.setsUser == self.setsToWin) {
//                // Match win for user
//                self.winner = "user"
//            }
//
//            // Check if match is won by opponent
//            if (self.setsOpponent == self.setsToWin) {
//                // Match loss for user
//                self.winner = "opponent"
//            }
//        }
//    }
    
}
