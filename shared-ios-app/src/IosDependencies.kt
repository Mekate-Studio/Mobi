package studio.mekate.mobi.ios

import platform.UIKit.UIViewController
import studio.mekate.mobi.di.SharedDependencies
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.ui.home.SharedHomeViewControllerFactory

// Platform composition only: native Home and Compose receive the same service.
object IosDependencies {
    fun createHomeFeatureService(): HomeFeatureService = SharedDependencies.createDefaultHomeFeatureService()

    fun createNearbyVehicleMapFeatureService(): NearbyVehicleMapFeatureService =
        SharedDependencies.createDefaultNearbyVehicleMapFeatureService()

    fun createSharedHomeViewController(service: HomeFeatureService): UIViewController =
        SharedHomeViewControllerFactory(service).create()
}
