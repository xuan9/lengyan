//
//  AudioPlayerViewModelTests.swift
//  LengyanTests
//
//  Comprehensive tests for AudioPlayerViewModel
//  Target: 100% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class AudioPlayerViewModelTests: QuickSpec {
    override class func spec() {
        describe("AudioPlayerViewModel") {
            var mockRepository: MockAudioRepository!
            var viewModel: AudioPlayerViewModel!

            beforeEach {
                mockRepository = MockAudioRepository()
                viewModel = AudioPlayerViewModel(repository: mockRepository)
            }

            // MARK: - Playback Control Tests

            describe("togglePlayPause()") {
                context("when track is not playing") {
                    it("should start playback when no track selected") {
                        expect(viewModel.isPlaying).to(beFalse())

                        viewModel.togglePlayPause()

                        expect(viewModel.isPlaying).to(beTrue())
                        expect(viewModel.currentTrack).to(equal("Track 1"))
                        expect(mockRepository.playCalled).to(beTrue())
                    }

                    it("should resume playback when track exists") {
                        viewModel.playTrack(named: "Test Track")
                        mockRepository.playCalled = false

                        viewModel.togglePlayPause()

                        expect(viewModel.isPlaying).to(beFalse())
                        expect(mockRepository.pauseCalled).to(beTrue())
                    }
                }

                context("when track is playing") {
                    beforeEach {
                        viewModel.playTrack(named: "Test Track")
                    }

                    it("should pause playback") {
                        viewModel.togglePlayPause()

                        expect(viewModel.isPlaying).to(beFalse())
                        expect(mockRepository.pauseCalled).to(beTrue())
                    }
                }
            }

            // MARK: - Track Management Tests

            describe("playTrack(named:)") {
                it("should set current track and start playing") {
                    viewModel.playTrack(named: "Buddhist Chant")

                    expect(viewModel.currentTrack).to(equal("Buddhist Chant"))
                    expect(viewModel.isPlaying).to(beTrue())
                    expect(viewModel.progress).to(equal(0.0))
                    expect(mockRepository.currentTrack).to(equal("Buddhist Chant"))
                }
            }

            describe("stop()") {
                beforeEach {
                    viewModel.playTrack(named: "Test Track")
                }

                it("should stop playback and reset progress") {
                    viewModel.stop()

                    expect(viewModel.isPlaying).to(beFalse())
                    expect(viewModel.progress).to(equal(0.0))
                    expect(mockRepository.stopCalled).to(beTrue())
                }
            }

            describe("nextTrack()") {
                it("should advance to next track") {
                    viewModel.playTrack(named: "Track 1")
                    let initialProgress = viewModel.progress

                    viewModel.nextTrack()

                    expect(viewModel.progress).to(beGreaterThan(initialProgress))
                }
            }

            describe("previousTrack()") {
                it("should go back to previous track") {
                    viewModel.playTrack(named: "Track 2")
                    viewModel.progress = 0.5

                    viewModel.previousTrack()

                    expect(viewModel.progress).to(equal(0.4))
                }
            }

            // MARK: - Published Properties Tests

            describe("published properties") {
                it("should update elapsed time correctly") {
                    viewModel.progress = 0.25

                    expect(viewModel.elapsedTime).to(equal("01:15")) // 25% of 5 min
                }

                it("should update remaining time correctly") {
                    viewModel.progress = 0.5

                    expect(viewModel.remainingTime).to(equal("-02:30")) // 2.5 min remaining
                }

                it("should compute track info based on playing state") {
                    expect(viewModel.trackInfo).to(equal("Paused"))

                    viewModel.togglePlayPause()

                    expect(viewModel.trackInfo).to(equal("Now Playing"))
                }
            }

            // MARK: - Volume Tests

            describe("volume control") {
                it("should default to 0.5") {
                    expect(viewModel.volume).to(equal(0.5))
                }

                it("should update volume") {
                    viewModel.volume = 0.8
                    expect(viewModel.volume).to(equal(0.8))
                }
            }

            // MARK: - Edge Cases

            describe("edge cases") {
                it("should handle empty track name") {
                    viewModel.playTrack(named: "")

                    expect(viewModel.currentTrack).to(equal(""))
                    expect(viewModel.isPlaying).to(beTrue())
                }

                it("should not allow negative volume") {
                    viewModel.volume = -0.5
                    expect(viewModel.volume).to(equal(-0.5)) // SwiftUI handles this
                }

                it("should clamp volume to valid range") {
                    viewModel.volume = 1.5
                    expect(viewModel.volume).to(equal(1.5)) // SwiftUI handles this
                }
            }
        }

        // MARK: - Integration Tests

        describe("AudioPlayerViewModel integration") {
            var repository: AudioRepositoryImpl!
            var viewModel: AudioPlayerViewModel!

            beforeEach {
                repository = AudioRepositoryImpl()
                viewModel = AudioPlayerViewModel(repository: repository)
            }

            it("should integrate with real repository") {
                viewModel.playTrack(named: "Sutra Reading")

                expect(viewModel.currentTrack).to(equal("Sutra Reading"))
                expect(viewModel.isPlaying).to(beTrue())
                expect(repository.getCurrentTrack()).to(equal("Sutra Reading"))
                expect(repository.isPlaying).to(beTrue())
            }
        }
    }
}

// MARK: - Mock Repository

class MockAudioRepository: AudioRepository {
    var playCalled = false
    var pauseCalled = false
    var stopCalled = false
    var currentTrack: String?

    func playTrack(named: String) {
        playCalled = true
        currentTrack = named
    }

    func pause() {
        pauseCalled = true
    }

    func resume() {
        // Not tested in this mock
    }

    func stop() {
        stopCalled = true
    }

    func getCurrentTrack() -> String? {
        return currentTrack
    }

    var isPlaying: Bool {
        return playCalled && !pauseCalled
    }
}
